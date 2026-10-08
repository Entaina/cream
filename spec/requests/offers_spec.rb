require "rails_helper"
require "zip"

RSpec.describe "Deal offers", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:pdf_bytes) { "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n" }

  def upload(content, type, filename)
    Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: filename)
  end

  def build_zip(entries)
    Zip::OutputStream.write_buffer do |zip|
      entries.each do |path, content|
        zip.put_next_entry(path)
        zip.write(content)
      end
    end.string
  end

  def create_offer!(name: "Oferta", html: "<p>x</p>")
    offer = deal.offers.create!(workspace: workspace, user: member, name: name)
    offer.versions.create!(user: member, html_body: html)
    offer
  end

  before { sign_in_as(member) }

  describe "creating an offer" do
    it "renders the new offer form" do
      get new_deal_offer_path(deal)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("offer_version[html_body]")
    end

    it "adds an offer by pasting HTML, as version 1" do
      expect {
        post deal_offers_path(deal), params: {offer: {name: "Oferta ACME"}, offer_version: {html_body: "<h1>Hola</h1>"}}
      }.to change(deal.offers, :count).by(1)

      expect(response).to redirect_to(deal_path(deal, tab: "offers"))
      offer = deal.offers.last
      expect(offer.user).to eq(member)
      expect(offer.workspace).to eq(workspace)
      expect(offer.versions.map(&:number)).to eq([1])
      expect(offer.current_version).not_to be_pdf
    end

    it "adds an offer by attaching a PDF, defaulting the name to the file name" do
      post deal_offers_path(deal), params: {offer_version: {file: upload(pdf_bytes, "application/pdf", "propuesta.pdf")}}

      offer = deal.offers.last
      expect(offer.name).to eq("propuesta")
      expect(offer.current_version).to be_pdf
    end

    it "adds an offer by attaching an HTML file" do
      post deal_offers_path(deal), params: {offer_version: {file: upload("<p>Oferta</p>", "text/html", "oferta.html")}}

      version = deal.offers.last.current_version
      expect(version).not_to be_pdf
      expect(version.html_content).to eq("<p>Oferta</p>")
    end

    it "adds an offer by attaching a ZIP with index.html and assets" do
      zip_bytes = build_zip(
        "site/index.html" => '<html><head><link rel="stylesheet" href="css/a.css"></head><body>Oferta</body></html>',
        "site/css/a.css" => "body { color: red; }"
      )

      post deal_offers_path(deal), params: {offer_version: {file: upload(zip_bytes, "application/zip", "paquete.zip")}}

      version = deal.offers.last.current_version
      expect(version).to be_zip
      expect(version.entry_path).to eq("site/index.html")
    end

    it "rejects a ZIP without HTML or with several HTML files and no index" do
      post deal_offers_path(deal), params: {offer_version: {file: upload(build_zip("readme.txt" => "hola"), "application/zip", "vacio.zip")}}
      expect(response).to have_http_status(:unprocessable_content)

      post deal_offers_path(deal), params: {
        offer_version: {file: upload(build_zip("a.html" => "<p>a</p>", "b.html" => "<p>b</p>"), "application/zip", "doble.zip")}
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(deal.offers.count).to eq(0)
    end

    it "rejects an offer without content, with both sources, or with another file type" do
      post deal_offers_path(deal), params: {offer: {name: "Vacía"}}
      expect(response).to have_http_status(:unprocessable_content)

      post deal_offers_path(deal), params: {offer: {name: "Doble"},
        offer_version: {html_body: "<p>x</p>", file: upload(pdf_bytes, "application/pdf", "a.pdf")}}
      expect(response).to have_http_status(:unprocessable_content)

      post deal_offers_path(deal), params: {offer: {name: "Texto"}, offer_version: {file: upload("plain text", "text/plain", "a.txt")}}
      expect(response).to have_http_status(:unprocessable_content)

      expect(deal.offers.count).to eq(0)
    end
  end

  describe "versions" do
    it "adds a new version that becomes the current one" do
      offer = create_offer!

      get new_deal_offer_version_path(deal, offer)
      expect(response).to have_http_status(:ok)

      expect {
        post deal_offer_versions_path(deal, offer), params: {offer_version: {html_body: "<p>v2</p>", comment: "Descuento"}}
      }.to change(offer.versions, :count).by(1)

      expect(response).to redirect_to(deal_path(deal, tab: "offers"))
      expect(offer.current_version.number).to eq(2)
      expect(offer.current_version.comment).to eq("Descuento")
    end

    it "rejects a version without content" do
      offer = create_offer!

      post deal_offer_versions_path(deal, offer), params: {offer_version: {comment: "nada"}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(offer.versions.count).to eq(1)
    end

    it "keeps numbering after removing a version" do
      offer = create_offer!
      second = offer.versions.create!(user: member, html_body: "<p>v2</p>")

      delete deal_offer_version_path(deal, offer, second)
      expect(offer.versions.count).to eq(1)

      post deal_offer_versions_path(deal, offer), params: {offer_version: {html_body: "<p>again</p>"}}
      expect(offer.current_version.number).to eq(2)
    end

    it "does not remove the last remaining version" do
      offer = create_offer!

      expect { delete deal_offer_version_path(deal, offer, offer.current_version) }.not_to change(offer.versions, :count)
      expect(response).to redirect_to(deal_path(deal, tab: "offers"))
    end
  end

  describe "preview" do
    it "previews pasted HTML sandboxed so it cannot run scripts" do
      offer = create_offer!(html: "<h1>Hola</h1><script>alert(1)</script>")

      get deal_offer_path(deal, offer)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to eq("<h1>Hola</h1><script>alert(1)</script>")
      expect(response.headers["Content-Security-Policy"]).to start_with("sandbox")
    end

    it "previews the current version by default and a specific version on demand" do
      offer = create_offer!(html: "<p>uno</p>")
      first = offer.current_version
      offer.versions.create!(user: member, html_body: "<p>dos</p>")

      get deal_offer_path(deal, offer)
      expect(response.body).to eq("<p>dos</p>")

      get deal_offer_version_path(deal, offer, first)
      expect(response.body).to eq("<p>uno</p>")
      expect(response.headers["Content-Security-Policy"]).to start_with("sandbox")
    end

    it "redirects ZIP previews to the signed package URL and serves assets with sandbox CSP" do
      zip_bytes = build_zip(
        "site/index.html" => "<html><head><link rel=\"stylesheet\" href=\"css/a.css\"></head><body>ZIP</body></html>",
        "site/css/a.css" => "body { font-weight: bold; }"
      )
      offer = deal.offers.create!(workspace: workspace, user: member, name: "ZIP")
      version = offer.versions.new(user: member)
      version.file.attach(io: StringIO.new(zip_bytes), filename: "paquete.zip", content_type: "application/zip")
      version.save!

      get deal_offer_path(deal, offer)
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("/offer_packages/")
      expect(response.location).to end_with("/site/index.html")

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("ZIP")
      csp = response.headers["Content-Security-Policy"]
      expect(csp).to include("sandbox")
      expect(csp).to include("allow-scripts")
      expect(csp).not_to include("allow-same-origin")

      get offer_package_file_path(token: version.package_token, path: "site/css/a.css")
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/css")
      expect(response.body).to include("font-weight")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end

    it "rewrites HTML base and root-absolute script URLs so JS loads from the package" do
      zip_bytes = build_zip(
        "site/index.html" => <<~HTML,
          <html><head><base href="/"><script src="/app.js?v=6"></script></head><body>ZIP</body></html>
        HTML
        "app.js" => "window.__offer = true;"
      )
      offer = deal.offers.create!(workspace: workspace, user: member, name: "ZIP")
      version = offer.versions.new(user: member)
      version.file.attach(io: StringIO.new(zip_bytes), filename: "paquete.zip", content_type: "application/zip")
      version.save!

      get offer_package_file_path(token: version.package_token, path: "site/index.html")
      expect(response.body).not_to include('<base href="/">')
      expect(response.body).to include('<base href="')
      expect(response.body).to include("/offer_packages/")
      expect(response.body).to include('src="../app.js?v=6"')

      get offer_package_file_path(token: version.package_token, path: "app.js")
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/javascript")
      expect(response.body).to include("window.__offer")
    end

    it "returns 404 for invalid, expired, or unsafe package paths" do
      zip_bytes = build_zip("index.html" => "<p>x</p>")
      offer = deal.offers.create!(workspace: workspace, user: member, name: "ZIP")
      version = offer.versions.new(user: member)
      version.file.attach(io: StringIO.new(zip_bytes), filename: "paquete.zip", content_type: "application/zip")
      version.save!

      get offer_package_file_path(token: "invalid", path: "index.html")
      expect(response).to have_http_status(:not_found)

      expired_token = version.package_token
      travel OfferVersion::PACKAGE_TOKEN_EXPIRY + 1.hour do
        get offer_package_file_path(token: expired_token, path: "index.html")
        expect(response).to have_http_status(:not_found)
      end

      get offer_package_file_path(token: version.package_token, path: "../secret")
      expect(response).to have_http_status(:not_found)

      get offer_package_file_path(token: version.package_token, path: "missing.css")
      expect(response).to have_http_status(:not_found)
    end

    it "previews a PDF inline" do
      offer = deal.offers.create!(workspace: workspace, user: member, name: "PDF")
      version = offer.versions.new(user: member)
      version.file.attach(io: StringIO.new(pdf_bytes), filename: "propuesta.pdf", content_type: "application/pdf")
      version.save!

      get deal_offer_path(deal, offer)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to start_with("inline")
      expect(response.body).to eq(pdf_bytes)
    end

    it "does not expose offers of deals from another workspace" do
      other_workspace = Workspace.create!(name: "Other", slug: "other-offers")
      other_deal = create_deal!(other_workspace)
      offer = other_deal.offers.create!(workspace: other_workspace, user: member, name: "Ajena")
      version = offer.versions.create!(user: member, html_body: "<p>x</p>")

      get deal_offer_path(other_deal, offer)
      expect(response).to have_http_status(:not_found)

      get deal_offer_version_path(other_deal, offer, version)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "lists offers with their versions in the deal's offers tab" do
    offer = create_offer!(name: "Oferta ACME")
    offer.versions.create!(user: member, html_body: "<p>v2</p>", comment: "Segunda ronda")

    get deal_path(deal, tab: "offers")

    expect(response.body).to include("Oferta ACME")
    expect(response.body).to include("Segunda ronda")
    expect(response.body).to include(deal_offer_path(deal, offer))
    expect(response.body).to include(deal_offer_version_path(deal, offer, offer.versions.first))
  end

  it "removes an offer and its versions" do
    offer = create_offer!

    expect { delete deal_offer_path(deal, offer) }.to change(deal.offers, :count).by(-1)
      .and change(OfferVersion, :count).by(-1)
    expect(response).to redirect_to(deal_path(deal, tab: "offers"))
  end
end
