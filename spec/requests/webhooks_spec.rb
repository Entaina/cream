require "rails_helper"

RSpec.describe "Webhooks", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    workspace.update!(webhooks_enabled: true)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:webhooks).and_return(true)
    sign_in_as(admin)
  end

  it "creates a webhook" do
    expect {
      post webhooks_path, params: {
        webhook: {url: "https://example.com/hook", events: ["record.created"], active: true}
      }
    }.to change(Webhook, :count).by(1)

    expect(response).to redirect_to(webhooks_path)
  end

  it "destroys a webhook" do
    webhook = workspace.webhooks.create!(user: admin, url: "https://example.com/hook", events: ["record.created"])

    expect {
      delete webhook_path(webhook)
    }.to change(Webhook, :count).by(-1)

    expect(response).to redirect_to(webhooks_path)
  end

  it "forbids non-admin members" do
    sign_in_as(salesperson)

    post webhooks_path, params: {
      webhook: {url: "https://example.com/hook", events: ["record.created"]}
    }

    expect(response).to redirect_to(root_path)
  end
end
