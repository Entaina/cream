require "rails_helper"

RSpec.describe "Email tracking", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:message) do
    workspaces(:one).email_messages.create!(
      user: users(:one), record: companies(:acme),
      to_address: "lead@example.com", subject: "Hi", body: "Hello"
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:email_tracking).and_return(true)
  end

  describe "GET /email_tracking/open/:token" do
    it "returns a transparent gif and records the open" do
      get email_tracking_open_path(token: message.tracking_token)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/gif")
      expect(message.reload).to be_opened
    end

    it "returns the gif without error for an unknown token" do
      get email_tracking_open_path(token: "does-not-exist")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/gif")
    end
  end

  describe "GET /email_tracking/click/:token" do
    it "records the click and redirects to the target URL" do
      get email_tracking_click_path(token: message.tracking_token, url: "https://example.com/pricing")

      expect(message.reload.clicks_count).to eq(1)
      expect(response).to redirect_to("https://example.com/pricing")
    end

    it "falls back to root for an unsafe (non-http) target" do
      get email_tracking_click_path(token: message.tracking_token, url: "javascript:alert(1)")

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when email_tracking is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:email_tracking).and_return(false)

      get email_tracking_click_path(token: message.tracking_token, url: "https://example.com")

      expect(response).to have_http_status(:not_found)
    end
  end
end
