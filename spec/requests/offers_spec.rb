require "rails_helper"

RSpec.describe "Deal offers", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:pdf_bytes) { "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n" }

  def upload(content, type, filename)
    Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: filename)
  end

  before { sign_in_as(member) }

  it "renders the new offer form" do
    get new_deal_offer_path(deal)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("offer[html_body]")
  end

  it "adds an offer by pasting HTML" do
    expect {
      post deal_offers_path(deal), params: {offer: {name: "Oferta ACME", html_body: "<h1>Hola</h1>"}}
    }.to change(deal.offers, :count).by(1)

    expect(response).to redirect_to(deal_path(deal, tab: "offers"))
    offer = deal.offers.last
    expect(offer.user).to eq(member)
    expect(offer.workspace).to eq(workspace)
    expect(offer).not_to be_pdf
  end

  it "adds an offer by attaching a PDF, defaulting the name to the file name" do
    post deal_offers_path(deal), params: {offer: {file: upload(pdf_bytes, "application/pdf", "propuesta.pdf")}}

    offer = deal.offers.last
    expect(offer.name).to eq("propuesta")
    expect(offer).to be_pdf
  end

  it "adds an offer by attaching an HTML file" do
    post deal_offers_path(deal), params: {offer: {file: upload("<p>Oferta</p>", "text/html", "oferta.html")}}

    offer = deal.offers.last
    expect(offer).not_to be_pdf
    expect(offer.html_content).to eq("<p>Oferta</p>")
  end

  it "rejects an offer without content, with both sources, or with another file type" do
    post deal_offers_path(deal), params: {offer: {name: "Vacía"}}
    expect(response).to have_http_status(:unprocessable_content)

    post deal_offers_path(deal), params: {offer: {name: "Doble", html_body: "<p>x</p>", file: upload(pdf_bytes, "application/pdf", "a.pdf")}}
    expect(response).to have_http_status(:unprocessable_content)

    post deal_offers_path(deal), params: {offer: {name: "Imagen", file: upload("plain text", "text/plain", "a.txt")}}
    expect(response).to have_http_status(:unprocessable_content)

    expect(deal.offers.count).to eq(0)
  end

  it "previews pasted HTML sandboxed so it cannot run scripts" do
    offer = deal.offers.create!(workspace: workspace, user: member, name: "Oferta", html_body: "<h1>Hola</h1><script>alert(1)</script>")

    get deal_offer_path(deal, offer)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to eq("<h1>Hola</h1><script>alert(1)</script>")
    expect(response.headers["Content-Security-Policy"]).to start_with("sandbox")
  end

  it "previews a PDF inline" do
    offer = deal.offers.new(workspace: workspace, user: member, name: "PDF")
    offer.file.attach(io: StringIO.new(pdf_bytes), filename: "propuesta.pdf", content_type: "application/pdf")
    offer.save!

    get deal_offer_path(deal, offer)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to start_with("inline")
    expect(response.body).to eq(pdf_bytes)
  end

  it "lists offers in the deal's offers tab" do
    deal.offers.create!(workspace: workspace, user: member, name: "Oferta ACME", html_body: "<p>x</p>")

    get deal_path(deal, tab: "offers")

    expect(response.body).to include("Oferta ACME")
    expect(response.body).to include(deal_offer_path(deal, deal.offers.last))
  end

  it "removes an offer" do
    offer = deal.offers.create!(workspace: workspace, user: member, name: "Oferta", html_body: "<p>x</p>")

    expect { delete deal_offer_path(deal, offer) }.to change(deal.offers, :count).by(-1)
    expect(response).to redirect_to(deal_path(deal, tab: "offers"))
  end

  it "does not expose offers of deals from another workspace" do
    other_workspace = Workspace.create!(name: "Other", slug: "other-offers")
    other_deal = create_deal!(other_workspace)
    offer = other_deal.offers.create!(workspace: other_workspace, user: member, name: "Ajena", html_body: "<p>x</p>")

    get deal_offer_path(other_deal, offer)

    expect(response).to have_http_status(:not_found)
  end
end
