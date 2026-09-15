require "rails_helper"

RSpec.describe "Lead submission consents", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "consent@example.com") }
  let(:lead_form) { create_lead_form!(workspace, user: member) }

  before { sign_in_as(member) }

  def create_consented_submission!(person:, lead_form:, deal: nil)
    version = Marketing::ConsentPolicySnapshot.capture(
      workspace: workspace,
      policy_html: "<p>Política de prueba</p>",
      statement_html: "<p>Acepto el tratamiento de datos</p>"
    )
    workspace.lead_submissions.create!(
      lead_form: lead_form,
      person: person,
      deal: deal,
      capture_destination: deal ? "deal" : "mql",
      data: { "email" => person.email, "gdpr_consent" => "1" },
      metadata: {
        "gdpr_consent_at" => Time.zone.parse("2026-09-14 10:00:00").iso8601,
        "privacy_policy_url" => "https://example.test/f/#{lead_form.slug}/privacy",
        "privacy_policy_hash" => version.content_hash
      },
      privacy_policy_version: version
    )
  end

  it "shows the accepted consent on the submission detail" do
    submission = create_consented_submission!(person: person, lead_form: lead_form)

    get person_lead_submission_path(person, submission)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Consentimiento aceptado")
    expect(response.body).to include("Política de prueba")
    expect(response.body).to include("Acepto el tratamiento de datos")
    expect(response.body).to include("overflow-y-auto")
  end

  it "links to the consent from the person Information tab" do
    create_consented_submission!(person: person, lead_form: lead_form)

    get person_path(person, tab: "information")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Formularios enviados")
    expect(response.body).to include("Ver consentimiento")
    expect(response.body).to include(person_lead_submission_path(person, person.lead_submissions.last))
  end

  it "shows the consent on the deal and links to the full detail" do
    deal = create_deal!(workspace, contacts: [person], company: person.company)
    submission = create_consented_submission!(person: person, lead_form: lead_form, deal: deal)

    get deal_path(deal, tab: "information")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ver consentimiento")
    expect(response.body).to include("Consentimiento aceptado")
    expect(response.body).to include("Política de prueba")
    expect(response.body).to include(person_lead_submission_path(person, submission))
  end

  it "links to the consent from the MQL pool" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
    type = workspace.subscription_types.find_by!(slug: "general")
    Marketing::ConsentService.subscribe!(person: person, subscription_type: type, source: "spec", legal_basis: "consent")
    submission = create_consented_submission!(person: person, lead_form: lead_form)

    get mqls_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ver consentimiento")
    expect(response.body).to include(person_lead_submission_path(person, submission))
  end

  it "redirects the submission detail when lead forms are disabled" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:lead_forms).and_return(false)
    submission = create_consented_submission!(person: person, lead_form: lead_form)

    get person_lead_submission_path(person, submission)

    expect(response).to redirect_to(root_path)
  end
end
