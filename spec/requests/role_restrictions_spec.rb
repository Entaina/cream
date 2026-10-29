require "rails_helper"

RSpec.describe "Role restrictions", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }

  def sign_in_to_workspace!(user)
    sign_in_as(user)
    patch switch_workspace_path, params: {workspace_id: workspace.id}
  end

  before { sign_in_to_workspace!(salesperson) }

  it "turns away salespeople creating products instead of failing" do
    expect { post products_path, params: {product: {name: "Blocked", price: 10}} }.not_to change(Product, :count)

    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq(I18n.t("auth.flashes.not_authorized"))
  end

  it "turns away salespeople editing pipelines" do
    patch pipeline_path(pipeline), params: {pipeline: {name: "Renamed"}}

    expect(response).to redirect_to(root_path)
    expect(pipeline.reload.name).not_to eq("Renamed")
  end

  it "lets salespeople add an edition from the deal product picker" do
    product = workspace.products.create!(name: "Course", price: 100)

    post product_editions_path(product, format: :json), params: {edition: {name: "Online 2026"}},
      headers: {"Accept" => "application/json"}

    expect(response).to have_http_status(:created)
  end

  it "does not let salespeople delete companies" do
    company = create_company!(workspace)

    delete company_path(company)

    expect(Company.exists?(company.id)).to be true
  end

  it "does not let salespeople edit someone else's note" do
    company = create_company!(workspace)
    note = company.notes.create!(body: "Original", user: admin, workspace: workspace)

    patch note_path(note), params: {note: {body: "Changed"}}

    expect(note.reload.body).to eq("Original")
  end

  it "lets salespeople edit their own note" do
    company = create_company!(workspace)
    note = company.notes.create!(body: "Original", user: salesperson, workspace: workspace)

    patch note_path(note), params: {note: {body: "Changed"}}

    expect(note.reload.body).to eq("Changed")
  end

  it "does not show Slack integrations or webhooks, whose URLs are secrets, to salespeople" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:slack_integrations).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:webhooks).and_return(true)
    workspace.update!(webhooks_enabled: true)
    workspace.slack_integrations.create!(webhook_url: "https://hooks.slack.com/services/T000/B000/secret-slack",
      notify_events: [SlackIntegration::NOTIFY_EVENTS.first])
    workspace.webhooks.create!(user: admin, url: "https://example.com/hook?key=secret-hook", events: [Webhook::EVENTS.first])

    get slack_integrations_path
    expect(response).to redirect_to(root_path)
    get webhooks_path
    expect(response).to redirect_to(root_path)

    follow_redirect!
    expect(response.body).not_to include("secret-slack", "secret-hook", slack_integrations_path, webhooks_path)

    sign_in_to_workspace!(admin)
    get root_path
    expect(response.body).to include(%(href="#{webhooks_path}"))
  end

  it "does not open another user's private email template by URL" do
    template = workspace.email_templates.create!(name: "Private", subject: "S", body: "<p>B</p>", user: admin, shared: false)

    get email_template_path(template)

    expect(response).to redirect_to(root_path)
  end
end
