require "rails_helper"

RSpec.describe ReportRunner do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }

  def run(metric:, group_by:, record_type: "Deal", date_range: "all", pipeline_id: nil, include_closed: false)
    described_class.new(workspace: workspace, record_type: record_type,
      metric: metric, group_by: group_by, date_range: date_range, pipeline_id: pipeline_id,
      include_closed: include_closed).run
  end

  it "counts deals grouped by stage" do
    create_deal!(workspace, pipeline: pipeline)
    create_deal!(workspace, pipeline: pipeline)

    result = run(metric: "count", group_by: "stage")

    expect(result.metric_label).to eq(I18n.t("reports.metrics.count"))
    expect(result.rows.sum(&:value)).to eq(2)
  end

  it "sums deal value grouped by owner with the owner's name as label" do
    owner = users(:one)
    create_deal!(workspace, pipeline: pipeline, value: 100, owner: owner)
    create_deal!(workspace, pipeline: pipeline, value: 250, owner: owner)

    result = run(metric: "sum_value", group_by: "owner")
    row = result.rows.find { |r| r.label == owner.name }

    expect(row.value).to eq(350.0)
  end

  it "labels a missing owner as Unassigned" do
    create_deal!(workspace, pipeline: pipeline)

    result = run(metric: "count", group_by: "owner")

    unassigned_label = I18n.t("reports.labels.unassigned")
    expect(result.rows.map(&:label)).to include(unassigned_label)
    unassigned = result.rows.find { |row| row.label == unassigned_label }
    expect(unassigned.key).to be_nil
  end

  it "exposes the grouping key on each row" do
    owner = users(:one)
    create_deal!(workspace, pipeline: pipeline, owner: owner)

    result = run(metric: "count", group_by: "owner")
    row = result.rows.find { |r| r.label == owner.name }

    expect(row.key).to eq(owner.id)
  end

  it "filters by the selected period" do
    create_deal!(workspace, pipeline: pipeline)

    expect(run(metric: "count", group_by: "stage", date_range: "month").total).to eq(1)
  end

  it "groups stages by name with pipeline segments when no pipeline is selected" do
    other = pipeline.duplicate(name: "Hiring").tap(&:save!)
    lead_in_default = pipeline.pipeline_stages.find_by!(name: "Lead")
    lead_in_other = other.pipeline_stages.find_by!(name: "Lead")
    create_deal!(workspace, pipeline: pipeline, stage: lead_in_default)
    create_deal!(workspace, pipeline: other, stage: lead_in_other)

    result = run(metric: "count", group_by: "stage", pipeline_id: nil)
    lead_row = result.rows.find { |row| row.label == "Lead" }

    expect(result.all_pipelines_stage_chart).to be(true)
    expect(lead_row.value).to eq(2)
    expect(lead_row.segments.map(&:pipeline_name)).to contain_exactly(pipeline.name, other.name)
  end

  it "filters deals by pipeline" do
    other_pipeline = pipeline.duplicate(name: "Hiring").tap(&:save!)
    create_deal!(workspace, pipeline: pipeline)
    create_deal!(workspace, pipeline: pipeline)
    create_deal!(workspace, pipeline: other_pipeline)

    result = run(metric: "count", group_by: "stage", pipeline_id: pipeline.id)

    expect(result.rows.sum(&:value)).to eq(2)
  end

  it "excludes closed-stage deals from the stage grouping by default" do
    won_stage = pipeline.pipeline_stages.find_by(name: "Won")
    create_deal!(workspace, pipeline: pipeline, stage: won_stage, name: "Won deal")

    result = run(metric: "count", group_by: "stage")

    expect(result.rows.map(&:label)).not_to include("Won")
  end

  it "includes closed-stage deals in the stage grouping when include_closed is true" do
    won_stage = pipeline.pipeline_stages.find_by(name: "Won")
    create_deal!(workspace, pipeline: pipeline, stage: won_stage, name: "Won deal")

    result = run(metric: "count", group_by: "stage", include_closed: true, pipeline_id: pipeline.id)

    expect(result.rows.map(&:label)).to include("Won")
  end

  it "ignores pipeline_id for non-deal record types" do
    create_person!(workspace)
    create_person!(workspace)

    result = run(metric: "count", group_by: "owner", record_type: "Person", pipeline_id: pipeline.id)

    expect(result.rows.sum(&:value)).to eq(2)
  end

  it "counts lead submissions grouped by utm source" do
    lead_form = create_lead_form!(workspace, user: users(:one))
    person = create_person!(workspace)
    workspace.lead_submissions.create!(
      lead_form: lead_form,
      person: person,
      deal: create_deal!(workspace, pipeline: pipeline),
      data: {"email" => person.email},
      metadata: {"utm_source" => "google"}
    )

    result = run(metric: "count", group_by: "utm_source", record_type: "LeadSubmission")

    expect(result.rows.find { |row| row.label == "google" }.value).to eq(1)
  end

  it "counts people grouped by lifecycle stage" do
    create_person!(workspace, lifecycle_stage: "lead")
    create_person!(workspace, lifecycle_stage: "mql")

    result = run(metric: "count", group_by: "lifecycle_stage", record_type: "Person")

    expect(result.rows.sum(&:value)).to eq(2)
  end
end
