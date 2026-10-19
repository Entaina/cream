require "rails_helper"
require "zip"

RSpec.describe "Api::V1::DealOffers", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:pdf_bytes) { "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n" }
  let(:pdf_payload) { {filename: "propuesta.pdf", content: Base64.strict_encode64(pdf_bytes), content_type: "application/pdf"} }

  def upload_offer(deal, offer_params, as_json: true)
    post "/api/v1/deals/#{deal.id}/offers", params: {offer: offer_params}, as: (:json if as_json), headers: headers
  end

  def create_offer!(name: "Oferta ACME", html: "<p>v1</p>")
    offer = deal.offers.create!(workspace: workspace, user: user, name: name)
    offer.versions.create!(user: user, html_body: html)
    offer
  end

  it "creates an offer with version 1 from a Base64 PDF, named after the file" do
    expect { upload_offer(deal, pdf_payload) }.to change(deal.offers, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("name" => "propuesta", "offer_created" => true, "versions_count" => 1)
    expect(response.parsed_body["version"]).to include(
      "number" => 1, "filename" => "propuesta.pdf", "content_type" => "application/pdf", "byte_size" => pdf_bytes.bytesize
    )
    offer = deal.offers.last
    expect(offer.user).to eq(user)
    expect(offer.workspace).to eq(workspace)
    expect(offer.current_version).to be_pdf
    expect(offer.current_version.file.download).to eq(pdf_bytes)
  end

  it "creates an offer from pasted HTML" do
    upload_offer(deal, {name: "Oferta ACME", html_body: "<h1>Hola</h1>", comment: "Primera"})

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["version"]).to include("number" => 1, "comment" => "Primera", "content_type" => "text/html")
    expect(deal.offers.last.current_version.html_body).to eq("<h1>Hola</h1>")
  end

  it "creates the uploaded version as a draft that clients cannot see" do
    upload_offer(deal, {name: "Oferta ACME", html_body: "<p>v1</p>"})

    expect(response.parsed_body["version"]).to include("draft" => true, "published_at" => nil)
    offer = deal.offers.last
    expect(offer.current_version).to be_draft
    expect(offer.client_version).to be_nil
  end

  it "adds a new version when an offer with that name already exists" do
    offer = create_offer!(name: "Oferta ACME")

    expect {
      upload_offer(deal, {name: "oferta acme", html_body: "<p>v2</p>", comment: "Descuento"})
    }.to change(offer.versions, :count).by(1).and change(deal.offers, :count).by(0)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("id" => offer.id, "offer_created" => false, "versions_count" => 2)
    expect(response.parsed_body["version"]).to include("number" => 2, "comment" => "Descuento")
    expect(offer.current_version.html_body).to eq("<p>v2</p>")
  end

  it "adds a new version to the deal's only offer when no name is given" do
    offer = create_offer!(name: "Oferta ACME")

    upload_offer(deal, pdf_payload)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("id" => offer.id, "name" => "Oferta ACME", "offer_created" => false)
    expect(response.parsed_body["version"]).to include("number" => 2, "filename" => "propuesta.pdf")
    expect(deal.offers.count).to eq(1)
  end

  it "adds a version to the offer chosen with offer_id" do
    create_offer!(name: "Otra")
    target = create_offer!(name: "Oferta ACME")

    upload_offer(deal, {offer_id: target.id, html_body: "<p>v2</p>"})

    expect(response).to have_http_status(:created)
    expect(target.versions.count).to eq(2)
  end

  it "creates a separate offer when the name matches none" do
    create_offer!(name: "Oferta ACME")

    upload_offer(deal, {name: "Oferta extra", html_body: "<p>x</p>"})

    expect(response.parsed_body).to include("name" => "Oferta extra", "offer_created" => true)
    expect(deal.offers.count).to eq(2)
  end

  it "asks which offer to use when the deal has several and none is chosen" do
    create_offer!(name: "Uno")
    create_offer!(name: "Dos")

    expect { upload_offer(deal, {html_body: "<p>x</p>"}) }.not_to change(OfferVersion, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"].first).to include("offer_id")
  end

  it "creates an offer from a Base64 ZIP with index.html" do
    zip_bytes = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("index.html")
      zip.write("<html><body>API ZIP</body></html>")
    end.string

    upload_offer(deal, {
      filename: "paquete.zip",
      content: Base64.strict_encode64(zip_bytes),
      content_type: "application/zip"
    })

    expect(response).to have_http_status(:created)
    version = deal.offers.last.current_version
    expect(version).to be_zip
    expect(version.entry_path).to eq("index.html")
    expect(response.parsed_body["version"]).to include("content_type" => "application/zip", "filename" => "paquete.zip")
  end

  it "uploads a file with multipart/form-data" do
    file = Rack::Test::UploadedFile.new(StringIO.new("<p>Oferta</p>"), "text/html", original_filename: "oferta.html")

    upload_offer(deal, {file: file}, as_json: false)

    expect(response).to have_http_status(:created)
    version = deal.offers.last.current_version
    expect(version.html_content).to eq("<p>Oferta</p>")
    expect(deal.offers.last.name).to eq("oferta")
  end

  it "rejects missing content, both sources, other file types and invalid Base64 without changes" do
    upload_offer(deal, {name: "Vacía"})
    expect(response).to have_http_status(:unprocessable_content)

    upload_offer(deal, pdf_payload.merge(name: "Doble", html_body: "<p>x</p>"))
    expect(response).to have_http_status(:unprocessable_content)

    upload_offer(deal, {name: "Texto", filename: "a.txt", content: Base64.strict_encode64("plain"), content_type: "text/plain"})
    expect(response).to have_http_status(:unprocessable_content)

    upload_offer(deal, {name: "Rota", filename: "a.pdf", content: "***"})
    expect(response).to have_http_status(:unprocessable_content)

    expect(deal.offers.count).to eq(0)
  end

  it "does not create a version on an existing offer when the content is invalid" do
    offer = create_offer!

    upload_offer(deal, {name: offer.name, comment: "sin contenido"})

    expect(response).to have_http_status(:unprocessable_content)
    expect(offer.versions.count).to eq(1)
  end

  it "rejects files over the size limit" do
    stub_const("Api::RecordAttachmentBuilder::MAX_FILE_SIZE", 4)

    upload_offer(deal, {filename: "a.html", content: Base64.strict_encode64("<p>12345</p>")})

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"].first).to include("exceeds")
    expect(deal.offers.count).to eq(0)
  end

  it "returns 404 for deals in other workspaces and for an offer_id of another deal" do
    other_deal = create_deal!(workspaces(:two))
    upload_offer(other_deal, {name: "x", html_body: "<p>x</p>"})
    expect(response).to have_http_status(:not_found)

    foreign = create_deal!(workspace, pipeline: pipeline, name: "Otro").offers
      .create!(workspace: workspace, user: user, name: "Ajena")
    upload_offer(deal, {offer_id: foreign.id, html_body: "<p>x</p>"})
    expect(response).to have_http_status(:not_found)
  end

  it "does not let an AI salesperson upload to a deal they do not own" do
    ai_user = users(:outsider)
    Membership.create!(user: ai_user, workspace: workspace, role: "ai_salesperson")
    ai_token = ai_user.api_tokens.create!(name: "AI", workspace: workspace)

    post "/api/v1/deals/#{deal.id}/offers", params: {offer: {name: "x", html_body: "<p>x</p>"}}, as: :json,
      headers: {"Authorization" => "Bearer #{ai_token.plaintext_token}"}

    expect(response).to have_http_status(:not_found) # not the owner: the deal is out of their scope
    expect(deal.offers.count).to eq(0)
  end

  it "requires authentication" do
    post "/api/v1/deals/#{deal.id}/offers", params: {offer: {html_body: "<p>x</p>"}}, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
