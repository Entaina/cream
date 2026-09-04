require "rails_helper"

RSpec.describe "Public landing pages", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:web_tracking).and_return(true)
  end

  it "renders a published landing page by slug" do
    template = workspace.lead_form_templates.create!(
      kind: "page",
      page_slug: "promo-verano",
      path: "public/pages/promo-verano",
      body: "<h1>Promo verano</h1><p>Oferta especial</p>"
    )

    get public_landing_page_path(workspace_slug: workspace.slug, slug: template.page_slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Promo verano")
    expect(response.body).to include("Oferta especial")
  end

  it "returns not found for unknown slugs" do
    get public_landing_page_path(workspace_slug: workspace.slug, slug: "missing-page")

    expect(response).to have_http_status(:not_found)
  end
end
