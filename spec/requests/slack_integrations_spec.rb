require "rails_helper"

RSpec.describe "SlackIntegrations", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:slack_integrations).and_return(true)
    sign_in_as(admin)
  end

  it "creates a slack integration" do
    expect {
      post slack_integrations_path, params: {
        slack_integration: {
          webhook_url: "https://hooks.slack.com/services/T/B/X",
          notify_events: ["deal.stage_changed"],
          active: true
        }
      }
    }.to change(SlackIntegration, :count).by(1)

    expect(response).to redirect_to(slack_integrations_path)
  end

  it "forbids non-admin members" do
    sign_in_as(salesperson)
    patch switch_workspace_path, params: {workspace_id: workspace.id}

    expect {
      post slack_integrations_path, params: {
        slack_integration: {webhook_url: "https://hooks.slack.com/services/T/B/X", notify_events: ["mention"]}
      }
    }.not_to change(SlackIntegration, :count)

    expect(response).to redirect_to(root_path)
  end
end
