require "rails_helper"

RSpec.describe "Deal visibility outside the deal pages", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { create_company!(workspace, name: "Shared Co") }
  let!(:own_deal) { create_deal!(workspace, pipeline: pipeline, company: company, owner: salesperson, name: "Own deal") }
  let!(:shared_deal) do
    create_deal!(workspace, pipeline: pipeline, company: company, owner: admin, name: "Shared deal").tap do |deal|
      DealAccess.create!(deal: deal, user: salesperson)
    end
  end
  let!(:hidden_deal) { create_deal!(workspace, pipeline: pipeline, company: company, owner: admin, name: "Hidden deal") }

  before do
    workspace.update!(salespeople_can_view_all_deals: false, salespeople_can_edit_all_deals: false)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
  end

  def sign_in_to_workspace!(user)
    sign_in_as(user)
    patch switch_workspace_path, params: {workspace_id: workspace.id}
  end

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  def email_on(record, subject)
    workspace.email_messages.create!(user: admin, record: record, to_address: "lead@example.com",
      subject: subject, body: "Body", status: "sent")
  end

  describe "dashboard recent activity" do
    it "hides activity on deals the salesperson cannot see" do
      sign_in_to_workspace!(salesperson)

      get root_path

      expect(response.body).to include("Own deal", "Shared deal")
      expect(response.body).not_to include("Hidden deal")
    end

    it "shows admins activity on every deal" do
      sign_in_to_workspace!(admin)

      get root_path

      expect(response.body).to include("Hidden deal")
    end

    it "keeps activity from other pipelines when a pipeline is selected" do
      other = pipeline.duplicate(name: "Partners").tap(&:save!)
      create_deal!(workspace, pipeline: other, owner: admin, name: "Partner deal")
      memberships(:one_one).update!(current_pipeline: pipeline)
      sign_in_to_workspace!(admin)

      get root_path

      expect(response.body).to include("Partner deal")
    end
  end

  describe "reports" do
    def run_report(viewer)
      ReportRunner.new(workspace: workspace, viewer: viewer, record_type: "Deal", metric: "count",
        group_by: "stage", date_range: "all").run
    end

    it "counts only the deals the viewer can see" do
      expect(run_report(context_for(salesperson)).rows.sum(&:value)).to eq(2)
      expect(run_report(context_for(admin)).rows.sum(&:value)).to eq(3)
    end

    it "runs the reports page as the signed-in user" do
      workspace.update!(reports_enabled: true)
      allow(ReportRunner).to receive(:new).and_call_original
      sign_in_to_workspace!(salesperson)

      get reports_path(record_type: "Deal", metric: "count", group_by: "stage")

      expect(response).to have_http_status(:ok)
      expect(ReportRunner).to have_received(:new)
        .with(hash_including(viewer: having_attributes(user: salesperson, workspace: workspace)))
    end

    it "runs scheduled reports as the report owner" do
      report = workspace.reports.create!(user: salesperson, name: "Weekly", record_type: "Deal", metric: "count",
        group_by: "stage", date_range: "all", schedule: "weekly")
      allow(ReportRunner).to receive(:new).and_call_original

      ReportMailer.scheduled_report(report).message

      expect(ReportRunner).to have_received(:new)
        .with(hash_including(viewer: having_attributes(user: salesperson, workspace: workspace)))
    end
  end

  describe "stage trigger runs" do
    it "lists only runs on deals the salesperson can see" do
      allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(true)
      trigger = workspace.stage_triggers.create!(name: "T", pipeline_stage: pipeline.first_stage,
        execution_mode: "llm", instructions: "x")
      trigger.runs.create!(workspace: workspace, deal: own_deal, status: "succeeded")
      trigger.runs.create!(workspace: workspace, deal: hidden_deal, status: "succeeded")
      sign_in_to_workspace!(salesperson)

      get stage_trigger_path(trigger)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Own deal")
      expect(response.body).not_to include("Hidden deal")
    end
  end

  describe "record emails" do
    before { allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true) }

    it "does not let a salesperson act on emails of hidden deals" do
      message = email_on(hidden_deal, "Hidden subject")
      sign_in_to_workspace!(salesperson)

      patch mark_replied_record_email_path(message)

      expect(response).to have_http_status(:not_found)
      expect(message.reload.replied_at).to be_nil
    end

    it "still lets a salesperson act on emails of their own deals" do
      message = email_on(own_deal, "Own subject")
      sign_in_to_workspace!(salesperson)

      patch mark_replied_record_email_path(message)

      expect(message.reload.replied_at).to be_present
    end
  end

  describe "tasks" do
    let(:person) { create_person!(workspace, first_name: "Lead") }
    let!(:hidden_task) { workspace.tasks.create!(title: "Hidden task", user: admin, assignee: admin, taskable: hidden_deal) }
    let!(:shared_task) { workspace.tasks.create!(title: "Shared task", user: admin, assignee: admin, taskable: shared_deal) }
    let!(:assigned_hidden_task) do
      workspace.tasks.create!(title: "Assigned hidden task", user: admin, assignee: salesperson, taskable: hidden_deal)
    end
    let!(:person_task) { workspace.tasks.create!(title: "Person task", user: admin, assignee: admin, taskable: person) }

    describe "web" do
      before { sign_in_to_workspace!(salesperson) }

      it "does not let a salesperson edit or complete a task on a deal they cannot see" do
        patch task_path(hidden_task), params: {task: {title: "Changed"}}
        patch toggle_task_path(hidden_task)

        expect(hidden_task.reload.title).to eq("Hidden task")
        expect(hidden_task).not_to be_completed
      end

      it "lets a salesperson edit tasks on deals they can edit, their own tasks and tasks on people" do
        patch task_path(shared_task), params: {task: {title: "Shared changed"}}
        patch task_path(assigned_hidden_task), params: {task: {title: "Assigned changed"}}
        patch toggle_task_path(person_task)

        expect(shared_task.reload.title).to eq("Shared changed")
        expect(assigned_hidden_task.reload.title).to eq("Assigned changed")
        expect(person_task.reload).to be_completed
      end

      it "shows tasks read-only on deals the salesperson can view but not edit" do
        workspace.update!(salespeople_can_view_all_deals: true)

        get deal_path(hidden_deal)

        expect(response.body).to include("Hidden task")
        expect(response.body).not_to include(toggle_task_path(hidden_task))
        expect(response.body).to include(toggle_task_path(assigned_hidden_task))

        patch task_path(hidden_task), params: {task: {title: "Changed"}}
        expect(hidden_task.reload.title).to eq("Hidden task")
      end
    end

    describe "REST API" do
      let(:headers) { {"Authorization" => "Bearer #{api_token_for(salesperson, workspace)}"} }

      it "lists only tasks the salesperson may see" do
        get "/api/v1/tasks", headers: headers

        titles = response.parsed_body.map { |task| task["title"] }
        expect(titles).to include("Shared task", "Assigned hidden task", "Person task")
        expect(titles).not_to include("Hidden task")
      end

      it "does not show, update or delete a task on a hidden deal" do
        get "/api/v1/tasks/#{hidden_task.id}", headers: headers
        expect(response).to have_http_status(:not_found)

        patch "/api/v1/tasks/#{hidden_task.id}", params: {task: {title: "Changed"}}, headers: headers
        delete "/api/v1/tasks/#{hidden_task.id}", headers: headers

        expect(hidden_task.reload.title).to eq("Hidden task")
      end
    end

    describe "MCP" do
      let(:plaintext) { api_token_for(salesperson, workspace) }

      it "lists only tasks the salesperson may see" do
        result = call_tool("list_tasks", {limit: 100})

        expect(result.to_json).to include("Shared task", "Assigned hidden task", "Person task")
        expect(result.to_json).not_to include("\"Hidden task\"")
      end

      it "does not complete or update a task on a hidden deal" do
        call_tool_raw("complete_task", {task_id: hidden_task.id})
        call_tool_raw("update_task", {task_id: hidden_task.id, title: "Changed"})

        expect(hidden_task.reload).not_to be_completed
        expect(hidden_task.title).to eq("Hidden task")
      end
    end
  end

  describe "MCP" do
    let(:plaintext) { api_token_for(salesperson, workspace) }

    before do
      email_on(own_deal, "Own subject")
      email_on(hidden_deal, "Hidden subject")
    end

    it "lists only visible deals on a company record" do
      result = call_tool("get_record", {record_type: "company", record_id: company.id})

      expect(result.to_json).to include("Own deal", "Shared deal")
      expect(result.to_json).not_to include("Hidden deal")
    end

    it "hides activity on hidden deals" do
      result = call_tool("list_activity", {limit: 100})

      expect(result.to_json).to include("Own deal")
      expect(result.to_json).not_to include("Hidden deal")
    end

    it "hides emails on hidden deals" do
      result = call_tool("list_emails", {limit: 100})

      expect(result.to_json).to include("Own subject")
      expect(result.to_json).not_to include("Hidden subject")
    end

    it "hides hidden deals from recent changes" do
      result = call_tool("recent_changes", {days: 7, limit: 100})

      expect(result.to_json).to include("Own deal")
      expect(result.to_json).not_to include("Hidden deal", "Hidden subject")
    end

    it "shows everything to admins" do
      result = call_tool("list_activity", {limit: 100}, token: api_token_for(admin, workspace))

      expect(result.to_json).to include("Hidden deal")
    end
  end
end
