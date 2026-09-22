require "rails_helper"

RSpec.describe "Reports", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    Pipeline.create_default!(workspace)
    workspace.update!(reports_enabled: true)
    sign_in_as(member)
  end

  describe "GET /reports" do
    it "renders the builder with computed results" do
      get reports_path(record_type: "Deal", metric: "count", group_by: "stage")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        I18n.t("reports.chart.heading",
          metric: Report.metric_label("count"),
          group: Report.group_by_label("stage"))
      )
    end

    it "falls back to defaults for an invalid combination" do
      get reports_path(record_type: "Person", metric: "sum_value", group_by: "stage")

      expect(response).to have_http_status(:ok)
    end

    it "exports the report as CSV" do
      get reports_path(record_type: "Deal", metric: "count", group_by: "stage", format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include("stage,#{Report.metric_label("count")}")
    end

    it "filters deal reports by pipeline" do
      pipeline = workspace.pipelines.first
      other_pipeline = pipeline.duplicate(name: "Hiring").tap(&:save!)
      create_deal!(workspace, pipeline: pipeline)
      create_deal!(workspace, pipeline: other_pipeline)

      get reports_path(record_type: "Deal", metric: "count", group_by: "stage", pipeline_id: pipeline.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("reports.results.total", value: 1))
    end

    it "defaults to the active pipeline when pipeline_id is omitted" do
      pipeline = workspace.pipelines.first
      other_pipeline = pipeline.duplicate(name: "Hiring").tap(&:save!)
      create_deal!(workspace, pipeline: pipeline)
      create_deal!(workspace, pipeline: other_pipeline)
      memberships(:one_one).update!(current_pipeline: pipeline)

      get reports_path(record_type: "Deal", metric: "count", group_by: "stage")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("reports.results.total", value: 1))
    end

    it "ignores an invalid pipeline_id" do
      get reports_path(record_type: "Deal", metric: "count", group_by: "stage", pipeline_id: 999_999)

      expect(response).to have_http_status(:ok)
    end

    it "hides closed stages from a count-by-stage report by default" do
      pipeline = workspace.pipelines.first
      won_stage = pipeline.pipeline_stages.find_by(name: "Won")
      create_deal!(workspace, pipeline: pipeline, name: "Open deal")
      create_deal!(workspace, pipeline: pipeline, stage: won_stage, name: "Won deal")

      get reports_path(record_type: "Deal", metric: "count", group_by: "stage", pipeline_id: pipeline.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Won</span>")
      expect(response.body).to include(I18n.t("reports.results.total", value: 1))
    end

    it "shows closed stages in a count-by-stage report when closed=1" do
      pipeline = workspace.pipelines.first
      won_stage = pipeline.pipeline_stages.find_by(name: "Won")
      create_deal!(workspace, pipeline: pipeline, name: "Open deal")
      create_deal!(workspace, pipeline: pipeline, stage: won_stage, name: "Won deal")

      get reports_path(record_type: "Deal", metric: "count", group_by: "stage",
        pipeline_id: pipeline.id, closed: "1")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Won</span>")
      expect(response.body).to include(I18n.t("reports.results.total", value: 2))
    end

    it "links each bar to the filtered deals list" do
      pipeline = workspace.pipelines.first
      stage = pipeline.pipeline_stages.first
      create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Linked deal")

      get reports_path(record_type: "Deal", metric: "count", group_by: "stage", pipeline_id: pipeline.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("stage=#{stage.id}")
      expect(response.body).to include("pipeline_id=#{pipeline.id}")
      expect(response.body).to include('href="/deals')
    end
  end

  describe "PATCH /reports/:id" do
    it "updates a report's email schedule" do
      report = workspace.reports.create!(user: member, name: "R", record_type: "Deal",
        metric: "count", group_by: "stage", date_range: "all")

      patch report_path(report), params: {report: {schedule: "weekly"}}

      expect(report.reload.schedule).to eq("weekly")
      expect(response).to redirect_to(reports_path)
    end
  end

  describe "POST /reports" do
    it "saves a report" do
      pipeline = workspace.pipelines.first

      expect {
        post reports_path, params: {
          report: {name: "Pipeline by stage", record_type: "Deal", metric: "count", group_by: "stage",
                   date_range: "all", pipeline_id: pipeline.id}
        }
      }.to change(Report, :count).by(1)

      saved = Report.last
      expect(saved.pipeline_id).to eq(pipeline.id)
      expect(response).to redirect_to(reports_path(saved.config_params))
    end

    it "rejects a pipeline for non-deal record types" do
      pipeline = workspace.pipelines.first

      expect {
        post reports_path, params: {
          report: {name: "Bad", record_type: "Person", metric: "count", group_by: "owner",
                   date_range: "all", pipeline_id: pipeline.id}
        }
      }.not_to change(Report, :count)
    end

    it "rejects a metric not valid for the record type" do
      expect {
        post reports_path, params: {
          report: {name: "Bad", record_type: "Person", metric: "sum_value", group_by: "owner", date_range: "all"}
        }
      }.not_to change(Report, :count)
    end
  end

  describe "DELETE /reports/:id" do
    it "deletes a saved report" do
      report = workspace.reports.create!(user: member, name: "R", record_type: "Deal",
        metric: "count", group_by: "stage", date_range: "all")

      expect { delete report_path(report) }.to change(Report, :count).by(-1)
    end
  end

  describe "when reports is disabled for the workspace" do
    before do
      workspace.update!(reports_enabled: false)
    end

    it "blocks and redirects to root" do
      get reports_path
      expect(response).to redirect_to(root_path)
    end
  end
end
