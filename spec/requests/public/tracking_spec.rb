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

    it "truncates url and referrer to 2048 characters" do
      long = "https://example.com/#{"a" * 5000}"

      post public_tracking_path, params: {workspace: workspace.slug, url: long, referrer: long}

      page_view = PageView.last
      expect(page_view.url.length).to eq(2048)
      expect(page_view.referrer.length).to eq(2048)
    end

    it "keeps a missing referrer as nil" do
      post public_tracking_path, params: {workspace: workspace.slug, url: "https://example.com/"}

      expect(PageView.last.referrer).to be_nil
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
