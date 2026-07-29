require "rails_helper"

RSpec.describe "Editions", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:outsider) { users(:outsider) }
  let(:workspace) { workspaces(:one) }

  describe "GET /editions" do
    it "lists editions for workspace members" do
      sign_in_as(member)
      workspace.editions.create!(name: "Madrid 2026", starts_on: Date.new(2026, 3, 1))

      get editions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Madrid 2026")
      expect(response.body).to include("Editions")
    end

    it "denies users without workspace membership" do
      sign_in_as(outsider)
      get editions_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /editions" do
    it "creates an edition in the current workspace" do
      sign_in_as(member)

      expect {
        post editions_path, params: {
          edition: { name: "Barcelona 2026", starts_on: "2026-09-01", ends_on: "2026-12-15" }
        }
      }.to change(workspace.editions, :count).by(1)

      edition = workspace.editions.find_by!(name: "Barcelona 2026")
      expect(edition.starts_on).to eq(Date.new(2026, 9, 1))
      expect(edition.ends_on).to eq(Date.new(2026, 12, 15))
      expect(response).to redirect_to(editions_path)
    end

    it "creates an edition via JSON for the record picker" do
      sign_in_as(member)

      post editions_path(format: :json), params: { edition: { name: "Online 2026" } },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["name"]).to eq("Online 2026")
      expect(body["id"]).to be_present
    end

    it "returns validation errors via JSON" do
      sign_in_as(member)
      workspace.editions.create!(name: "Duplicate")

      post editions_path(format: :json), params: { edition: { name: "duplicate" } },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end
  end

  describe "GET /editions/picker" do
    it "returns matching editions with date hints" do
      sign_in_as(member)
      edition = workspace.editions.create!(
        name: "Madrid 2026",
        starts_on: Date.new(2026, 3, 1),
        ends_on: Date.new(2026, 6, 30)
      )
      workspace.editions.create!(name: "Barcelona 2027")

      get picker_editions_path(format: :json), params: { q: "madrid" },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:success)
      results = response.parsed_body
      expect(results.size).to eq(1)
      expect(results.first["id"]).to eq(edition.id)
      expect(results.first["name"]).to eq("Madrid 2026")
      expect(results.first["hint"]).to include("Mar")
    end

    it "does not leak editions from other workspaces" do
      sign_in_as(member)
      workspaces(:two).editions.create!(name: "Secret cohort")

      get picker_editions_path(format: :json), params: { q: "secret" },
        headers: { "Accept" => "application/json" }

      expect(response.parsed_body).to eq([])
    end
  end

  describe "PATCH /editions/:id" do
    it "updates edition dates" do
      sign_in_as(member)
      edition = workspace.editions.create!(name: "Madrid 2026")

      patch edition_path(edition), params: {
        edition: { starts_on: "2026-04-01", ends_on: "2026-07-01" }
      }

      expect(response).to redirect_to(editions_path)
      expect(edition.reload.starts_on).to eq(Date.new(2026, 4, 1))
    end
  end

  describe "DELETE /editions/:id" do
    it "deletes an unused edition" do
      sign_in_as(member)
      edition = workspace.editions.create!(name: "Unused")

      expect {
        delete edition_path(edition)
      }.to change(workspace.editions, :count).by(-1)

      expect(response).to redirect_to(editions_path)
    end

    it "blocks deletion when the edition is in use" do
      sign_in_as(member)
      pipeline = Pipeline.create_default!(workspace)
      deal = create_deal!(workspace, pipeline: pipeline)
      product = workspace.products.create!(name: "Course", price: 100)
      edition = workspace.editions.create!(name: "In use")
      deal.deal_products.create!(product: product, quantity: 1, edition: edition)

      expect {
        delete edition_path(edition)
      }.not_to change(workspace.editions, :count)

      expect(response).to redirect_to(editions_path)
      expect(flash[:alert]).to eq("Can't delete an edition in use by a deal.")
    end
  end
end
