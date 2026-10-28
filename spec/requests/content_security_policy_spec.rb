require "rails_helper"

RSpec.describe "Content security policy", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let!(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "agenda-csp",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"],
      active: true
    )
    page.event_types.build(
      slug: "video",
      name_i18n: {"es" => "Online"},
      duration_minutes: 30,
      location_type: "google_meet",
      weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 0,
      visible: true
    )
    page.save!
    page
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
    allow(TurnstileVerifier).to receive_messages(enabled?: true, site_key: "site-key-123")
  end

  def directive(policy, name)
    policy.split(";").map(&:strip).find { |part| part.start_with?("#{name} ") }
  end

  it "reports violations without enforcing the policy" do
    get new_session_path

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Security-Policy"]).to be_nil
    policy = response.headers["Content-Security-Policy-Report-Only"]
    expect(policy).to include("object-src 'none'")
    expect(policy).to include("base-uri 'self'")
  end

  it "allows Turnstile on the public booking page with a per-request nonce" do
    get public_booking_page_path(booking_page.slug)

    policy = response.headers["Content-Security-Policy-Report-Only"]
    script_src = directive(policy, "script-src")
    expect(script_src).to include("'self'", "https://challenges.cloudflare.com")
    expect(directive(policy, "frame-src")).to include("https://challenges.cloudflare.com")

    nonce = script_src[/'nonce-([^']+)'/, 1]
    expect(nonce).to be_present
    expect(response.body).to match(%r{<script[^>]+src="https://challenges\.cloudflare\.com/turnstile/v0/api\.js"[^>]+nonce="#{Regexp.escape(nonce)}"})
    expect(response.body).to include(%(<meta name="csp-nonce" content="#{nonce}"))

    get public_booking_page_path(booking_page.slug)
    expect(directive(response.headers["Content-Security-Policy-Report-Only"], "script-src")).not_to include(nonce)
  end
end
