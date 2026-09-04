require "rails_helper"

RSpec.describe "Marketing admin access", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_segments).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
  end

  describe "campaigns" do
    it "allows admins to create campaigns" do
      sign_in_as(admin)

      expect {
        post campaigns_path, params: { campaign: { name: "Q1 launch", status: "draft" } }
      }.to change(Campaign, :count).by(1)

      expect(response).to redirect_to(Campaign.last)
    end

    it "blocks salespeople from creating campaigns" do
      sign_in_as(salesperson)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      expect {
        post campaigns_path, params: { campaign: { name: "Blocked", status: "draft" } }
      }.not_to change(Campaign, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "journeys" do
    it "allows admins to create journeys" do
      sign_in_as(admin)

      expect {
        post journeys_path, params: {
          journey: {
            name: "Welcome",
            entry_trigger: "manual",
            steps_attributes: {
              "0" => { position: "0", step_type: "wait", config: { minutes: "5" } }
            }
          }
        }
      }.to change(Journey, :count).by(1)

      expect(response).to redirect_to(Journey.last)
    end

    it "blocks salespeople from creating journeys" do
      sign_in_as(salesperson)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      expect {
        post journeys_path, params: {
          journey: { name: "Blocked", entry_trigger: "manual" }
        }
      }.not_to change(Journey, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "segments" do
    it "allows admins to list segments" do
      sign_in_as(admin)

      get segments_path

      expect(response).to have_http_status(:ok)
    end

    it "blocks salespeople from listing segments" do
      sign_in_as(salesperson)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      get segments_path

      expect(response).to redirect_to(root_path)
    end

    it "allows admins to create segments" do
      sign_in_as(admin)

      expect {
        post segments_path, params: {
          segment: { name: "Hot leads", record_type: "Person", filters: {} }
        }
      }.to change(Segment, :count).by(1)

      expect(response).to redirect_to(Segment.last)
    end

    it "blocks salespeople from creating segments" do
      sign_in_as(salesperson)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      expect {
        post segments_path, params: {
          segment: { name: "Blocked", record_type: "Person", filters: {} }
        }
      }.not_to change(Segment, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
