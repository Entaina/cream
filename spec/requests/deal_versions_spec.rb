require "rails_helper"

RSpec.describe "Deal versions", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }

  before { sign_in_as(member) }

  describe "GET /deals/:deal_id/versions" do
    it "lists versions for the deal" do
      deal.update!(name: "Updated deal name")

      get deal_versions_path(deal)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("deal_versions.history"))
      expect(response.body).to include("Updated deal name").or include("Name")
    end

    it "does not expose deals from other workspaces" do
      other_workspace = workspaces(:two)
      other_pipeline = Pipeline.create_default!(other_workspace)
      other_deal = create_deal!(other_workspace, pipeline: other_pipeline)

      get deal_versions_path(other_deal)

      expect(response).to have_http_status(:not_found)
    end

    it "includes notes and comments in the audit timeline" do
      Note.create!(workspace: workspace, notable: deal, user: member, body: "Follow-up call notes")
      Comment.create!(workspace: workspace, commentable: deal, user: member, body: "Looks promising")

      get deal_versions_path(deal)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.note_added", actor: member.name))
      expect(response.body).to include(I18n.t("activities.comment_added", actor: member.name))
    end
  end

  describe "GET /deals/:deal_id/versions/:id" do
    it "shows a version snapshot" do
      deal.update!(probability: 25)
      version = deal.versions.last

      get deal_version_path(deal, version)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("deal_versions.snapshot"))
      expect(response.body).to include(Deal.human_attribute_name(:probability))
    end

    it "rejects versions outside the current workspace scope" do
      version = deal.versions.last
      version.update_column(:workspace_id, workspaces(:two).id)

      get deal_version_path(deal, version)

      expect(response).to have_http_status(:not_found)
    end
  end
end
