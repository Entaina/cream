require "rails_helper"

RSpec.describe "Public web tracking", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:web_tracking).and_return(true)
  end

  describe "POST /t" do
    it "records a page view" do
      expect {
        post public_tracking_path, params: {
          workspace: workspace.slug,
          url: "https://example.com/pricing",
          utm_source: "google"
        }
      }.to change(PageView, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(PageView.last.utm_source).to eq("google")
    end
  end

  describe "GET /cream.js" do
    it "serves the tracking snippet" do
      get cream_tracking_script_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/javascript")
    end
  end
end
