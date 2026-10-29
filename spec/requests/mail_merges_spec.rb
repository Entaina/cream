require "rails_helper"

RSpec.describe "Mail merges", type: :request do
  fixtures :users, :workspaces, :memberships, :companies, :saved_views

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before { sign_in_as(member) }

  shared_context "with mail merge enabled" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:mail_merge).and_return(true)
    end
  end

  describe "POST /mail_merge (manual source)" do
    include_context "with mail merge enabled"

    it "enqueues the job with the parsed record IDs" do
      people = [
        create_person!(workspace, company: companies(:acme)),
        create_person!(workspace, company: companies(:acme), email: "second@example.com"),
        create_person!(workspace, company: companies(:acme), email: "third@example.com")
      ]
      ids = people.map { |person| person.id.to_s }.join(", ")

      post mail_merge_path, params: {
        source: "manual", record_type: "Person", record_ids: " #{ids} ",
        subject: "Hi {name}", body: "Hello"
      }

      expect(MailMergeJob).to have_been_enqueued.with(
        workspace.id, member.id, "Person", people.map { |p| p.id.to_s }, "Hi {name}", "Hello", nil
      )
      expect(response).to redirect_to(mail_merge_path(record_type: "Person"))
    end
  end

  describe "POST /mail_merge (saved view source)" do
    include_context "with mail merge enabled"

    it "resolves the view's records and derives the record type from the view" do
      at_acme = create_person!(workspace, company: companies(:acme))
      create_person!(workspace, company: create_company!(workspace, name: "Other Inc"))
      view = saved_views(:person_shared) # filters company_id = acme

      post mail_merge_path, params: {source: "view:#{view.id}", subject: "Hi", body: "Hello"}

      expect(MailMergeJob).to have_been_enqueued.with(
        workspace.id, member.id, "Person", [at_acme.id.to_s], "Hi", "Hello", nil
      )
    end
  end

  describe "POST /mail_merge (list source)" do
    include_context "with mail merge enabled"

    it "resolves the list entries and derives the record type from the list" do
      person = create_person!(workspace, company: companies(:acme))
      list = workspace.lists.create!(name: "Targets", record_type: "Person")
      list.list_entries.create!(record: person)

      post mail_merge_path, params: {source: "list:#{list.id}", subject: "Hi", body: "Hello"}

      expect(MailMergeJob).to have_been_enqueued.with(
        workspace.id, member.id, "Person", [person.id.to_s], "Hi", "Hello", nil
      )
    end
  end

  describe "POST /mail_merge with no recipients" do
    include_context "with mail merge enabled"

    it "does not enqueue and redirects with an alert" do
      post mail_merge_path, params: {source: "manual", record_type: "Person", record_ids: ""}

      expect(MailMergeJob).not_to have_been_enqueued
      expect(response).to redirect_to(mail_merge_path(record_type: "Person"))
    end
  end

  describe "GET /mail_merge/recipients_count" do
    include_context "with mail merge enabled"

    it "returns the resolved recipient count as JSON" do
      create_person!(workspace, company: companies(:acme))
      view = saved_views(:person_shared)

      get recipients_count_mail_merge_path(source: "view:#{view.id}")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("count" => 1, "record_type" => "Person")
    end
  end

  describe "when mail_merge is disabled" do
    it "blocks the action and redirects to root" do
      post mail_merge_path, params: {source: "manual", record_type: "Person", record_ids: "1"}

      expect(MailMergeJob).not_to have_been_enqueued
      expect(response).to redirect_to(root_path)
    end
  end

  describe "deal visibility" do
    include_context "with mail merge enabled"

    let(:admin) { users(:one) }
    let(:salesperson) { users(:two) }
    let!(:pipeline) { Pipeline.create_default!(workspace) }
    let!(:hidden_deal) do
      create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Hidden merge deal")
    end

    before do
      workspace.update!(salespeople_can_view_all_deals: false)
      sign_in_as(salesperson)
      patch switch_workspace_path, params: {workspace_id: workspace.id}
    end

    it "drops hidden deals from a manual source" do
      post mail_merge_path, params: {
        source: "manual", record_type: "Deal", record_ids: hidden_deal.id.to_s,
        subject: "Hi", body: "Hello"
      }

      expect(MailMergeJob).not_to have_been_enqueued
      expect(response).to redirect_to(mail_merge_path(record_type: "Deal"))
      expect(flash[:alert]).to eq(I18n.t("flashes.mail_merges.no_recipients"))
    end

    it "drops hidden deals from a list source" do
      list = workspace.lists.create!(name: "Deals", record_type: "Deal")
      list.list_entries.create!(record: hidden_deal)

      post mail_merge_path, params: {source: "list:#{list.id}", subject: "Hi", body: "Hello"}

      expect(MailMergeJob).not_to have_been_enqueued
      expect(response).to redirect_to(mail_merge_path(record_type: "Deal"))
    end
  end

  describe "private email templates" do
    include_context "with mail merge enabled"

    let(:owner) { users(:one) }
    let(:other_member) { users(:two) }
    let!(:private_template) do
      workspace.email_templates.create!(
        user: owner, name: "Private", subject: "Hi", body: "Secret", shared: false
      )
    end
    let(:person) { create_person!(workspace, company: companies(:acme)) }

    before do
      sign_in_as(other_member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}
    end

    it "rejects another user's private template" do
      post mail_merge_path, params: {
        source: "manual", record_type: "Person", record_ids: person.id.to_s,
        subject: "Hi", body: "Hello", template_id: private_template.id
      }

      expect(MailMergeJob).not_to have_been_enqueued
      expect(response).to have_http_status(:not_found)
    end
  end
end
