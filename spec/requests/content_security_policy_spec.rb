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

  it "enforces the policy on app pages" do
    get new_session_path

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Security-Policy-Report-Only"]).to be_nil
    policy = response.headers["Content-Security-Policy"]
    expect(policy).to include("object-src 'none'")
    expect(policy).to include("base-uri 'self'")
    expect(directive(policy, "script-src")).to match(/'nonce-[^']+'/)
    expect(directive(policy, "script-src")).not_to include("'unsafe-inline'")
    expect(directive(policy, "style-src")).to include("https://fonts.googleapis.com")
    expect(directive(policy, "connect-src")).to include("wss:")
  end

  it "enforces the policy inside the signed-in app" do
    sign_in_as(user)

    get deals_path

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Security-Policy"]).to include("object-src 'none'")
    expect(response.headers["Content-Security-Policy-Report-Only"]).to be_nil
  end

  it "allows the Swagger UI bundle and its nonced bootstrap script on the API docs" do
    get api_docs_path

    policy = response.headers["Content-Security-Policy"]
    script_src = directive(policy, "script-src")
    expect(script_src).to include("https://cdn.jsdelivr.net")
    expect(directive(policy, "style-src")).to include("https://cdn.jsdelivr.net")
    nonce = script_src[/'nonce-([^']+)'/, 1]
    expect(response.body).to include(%(<script nonce="#{nonce}">))
  end

  it "keeps public lead forms embeddable without adding the app policy" do
    allow(CreamFeatures).to receive(:enabled?).with(:lead_forms).and_return(true)
    lead_form = create_lead_form!(workspace, user: user)

    get public_lead_form_path(lead_form.slug)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Security-Policy"]).to eq("frame-ancestors *")
    expect(response.headers["Content-Security-Policy-Report-Only"]).to be_nil
  end

  it "only reports on the client portal, which renders the workspace layout template" do
    allow(CreamFeatures).to receive(:enabled?).with(:client_portal).and_return(true)

    get client_portal_root_path(workspace_slug: workspace.slug)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Security-Policy"]).to be_nil
    expect(response.headers["Content-Security-Policy-Report-Only"]).to include("object-src 'none'")
  end

  it "only reports on the template preview, which renders the template as published" do
    sign_in_as(user)
    import_lead_form_templates!(workspace)
    template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")

    get preview_lead_form_template_path(template)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Security-Policy"]).to be_nil
    expect(response.headers["Content-Security-Policy-Report-Only"]).to include("object-src 'none'")

    get lead_form_templates_path
    expect(response.headers["Content-Security-Policy"]).to include("object-src 'none'")
  end

  it "keeps inline event handlers out of app views, which the enforced policy blocks" do
    handler = /\son[a-z]+=["']|\bon[a-z]+:\s*["']/
    offenders = Rails.root.glob("app/{views,helpers,components}/**/*.{erb,rb}").filter_map do |path|
      path.relative_path_from(Rails.root).to_s if path.read.match?(handler)
    end

    expect(offenders).to be_empty
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
