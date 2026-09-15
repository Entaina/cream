require "rails_helper"

RSpec.describe "Editions", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:outsider) { users(:outsider) }
  let(:workspace) { workspaces(:one) }
  let(:product) { workspace.products.create!(name: "Course", price: 100) }

  describe "POST /products/:product_id/editions" do
    it "creates an edition for the product" do
      sign_in_as(member)

      expect {
        post product_editions_path(product), params: {
          edition: {name: "Barcelona 2026", starts_on: "2026-09-01", ends_on: "2026-12-15"}
        }
      }.to change(product.editions, :count).by(1)

      edition = product.editions.find_by!(name: "Barcelona 2026")
      expect(edition.starts_on).to eq(Date.new(2026, 9, 1))
      expect(edition.ends_on).to eq(Date.new(2026, 12, 15))
      expect(edition.workspace).to eq(workspace)
      expect(response).to redirect_to(edit_product_path(product))
    end

    it "creates an edition via JSON for the record picker" do
      sign_in_as(member)

      post product_editions_path(product, format: :json), params: {edition: {name: "Online 2026"}},
        headers: {"Accept" => "application/json"}

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["name"]).to eq("Online 2026")
      expect(body["id"]).to be_present
    end

    it "returns validation errors via JSON" do
      sign_in_as(member)
      product.editions.create!(name: "Duplicate")

      post product_editions_path(product, format: :json), params: {edition: {name: "duplicate"}},
        headers: {"Accept" => "application/json"}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "denies users without workspace membership" do
      sign_in_as(outsider)
      post product_editions_path(product), params: {edition: {name: "Blocked"}}
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /products/:product_id/editions/picker" do
    it "returns matching editions with date hints" do
      sign_in_as(member)
      edition = product.editions.create!(
        name: "Madrid 2026",
        starts_on: Date.new(2026, 3, 1),
        ends_on: Date.new(2026, 6, 30)
      )
      product.editions.create!(name: "Barcelona 2027")

      get picker_product_editions_path(product, format: :json), params: {q: "madrid"},
        headers: {"Accept" => "application/json"}

      expect(response).to have_http_status(:success)
      results = response.parsed_body
      expect(results.size).to eq(1)
      expect(results.first["id"]).to eq(edition.id)
      expect(results.first["name"]).to eq("Madrid 2026")
      expect(results.first["hint"]).to include(I18n.l(Date.new(2026, 3, 1), format: :short))
    end

    it "does not return editions from other products" do
      sign_in_as(member)
      other_product = workspace.products.create!(name: "Other", price: 50)
      other_product.editions.create!(name: "Secret cohort")

      get picker_product_editions_path(product, format: :json), params: {q: "secret"},
        headers: {"Accept" => "application/json"}

      expect(response.parsed_body).to eq([])
    end
  end

  describe "PATCH /products/:product_id/editions/:id" do
    it "updates edition dates" do
      sign_in_as(member)
      edition = product.editions.create!(name: "Madrid 2026")

      patch product_edition_path(product, edition), params: {
        edition: {starts_on: "2026-04-01", ends_on: "2026-07-01"}
      }

      expect(response).to redirect_to(edit_product_path(product))
      expect(edition.reload.starts_on).to eq(Date.new(2026, 4, 1))
    end
  end

  describe "DELETE /products/:product_id/editions/:id" do
    it "deletes an unused edition" do
      sign_in_as(member)
      edition = product.editions.create!(name: "Unused")

      expect {
        delete product_edition_path(product, edition)
      }.to change(product.editions, :count).by(-1)

      expect(response).to redirect_to(edit_product_path(product))
    end

    it "blocks deletion when the edition is in use" do
      sign_in_as(member)
      pipeline = Pipeline.create_default!(workspace)
      deal = create_deal!(workspace, pipeline: pipeline)
      edition = product.editions.create!(name: "In use")
      deal.deal_products.create!(product: product, quantity: 1, edition: edition)

      expect {
        delete product_edition_path(product, edition)
      }.not_to change(product.editions, :count)

      expect(response).to redirect_to(edit_product_path(product))
      expect(flash[:alert]).to eq("Can't delete an edition in use by a deal.")
    end
  end
end
