require "rails_helper"

RSpec.describe "Email tracking", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:message) do
    workspace.email_messages.create!(
      user: users(:one), record: companies(:acme),
      to_address: "lead@example.com", subject: "Hi", body: "Hello"
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:email_tracking).and_return(true)
  end

  # Query params of the first tracked link LinkRewriter produces for the message body.
  def tracked_click_params(message)
    html = Marketing::LinkRewriter.rewrite(html: message.body, message: message, campaign: message.campaign)
    tracked = html[/href="([^"]+)"/, 1]
    URI.decode_www_form(URI.parse(tracked).query).to_h
  end

  def click(message, url:, sig: nil)
    get email_tracking_click_path({token: message.tracking_token, url: url, sig: sig}.compact)
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
    let(:campaign) do
      workspace.campaigns.create!(name: "Otoño", status: "sent", utm_source: "newsletter", utm_campaign: "otoño 2026")
    end

    before do
      message.update!(
        campaign: campaign,
        body: %(<p><a href="https://example.com/pricing?plan=pro&amp;ref=a,b">Precios</a></p>)
      )
    end

    it "records the click and redirects a signed link" do
      params = tracked_click_params(message)

      click(message, url: params["url"], sig: params["sig"])

      expect(message.reload.clicks_count).to eq(1)
      expect(response).to redirect_to(params["url"])
    end

    it "redirects an unsigned link from an email sent before signing" do
      params = tracked_click_params(message)

      click(message, url: params["url"])

      expect(response).to redirect_to(params["url"])
    end

    it "redirects an unsigned link whose campaign utm params changed after sending" do
      url = tracked_click_params(message)["url"]
      campaign.update!(utm_source: "renamed", utm_medium: "email")

      click(message, url: url)

      expect(response).to redirect_to(url)
    end

    it "redirects a signed link even if the email body no longer contains it" do
      params = tracked_click_params(message)
      message.update!(body: "Edited")

      click(message, url: params["url"], sig: params["sig"])

      expect(response).to redirect_to(params["url"])
    end

    it "asks for confirmation before following a destination that is not in the email" do
      allow(Rails.logger).to receive(:warn).and_call_original

      click(message, url: "https://evil.example/phish")

      expect(response).to have_http_status(:ok)
      expect(message.reload.clicks_count).to eq(1)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("a[href='https://evil.example/phish']").text).to eq(I18n.t("public.email_tracking_leaving.continue"))
      expect(response.body).to include("evil.example")
      expect(Rails.logger).to have_received(:warn).with(/Unverified click target.*evil\.example/)
    end

    it "asks for confirmation when the signature does not match" do
      click(message, url: "https://evil.example/phish", sig: "invalid")

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css("a[href='https://evil.example/phish']")).to be_present
    end

    it "falls back to root for an unsafe (non-http) target" do
      click(message, url: "javascript:alert(1)")

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when email_tracking is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:email_tracking).and_return(false)

      click(message, url: "https://example.com")

      expect(response).to have_http_status(:not_found)
    end
  end
end
