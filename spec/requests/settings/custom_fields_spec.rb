require "rails_helper"

RSpec.describe "Settings::CustomFields", type: :request do
  fixtures :users, :workspaces, :memberships, :custom_fields

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let(:field) { custom_fields(:person_tier) }

  before do
    sign_in_as(admin)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "GET /settings/custom_fields" do
    it "lists custom fields for members" do
      get settings_custom_fields_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Customer tier")
    end
  end

  describe "POST /settings/custom_fields" do
    it "creates a custom field for admins" do
      expect {
        post settings_custom_fields_path, params: {
          custom_field: {
            name: "Lead source", record_type: "Person", field_type: "text", required: false
          }
        }
      }.to change(CustomField, :count).by(1)

      expect(response).to redirect_to(settings_custom_fields_path)
    end

    it "forbids members from creating fields" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      expect {
        post settings_custom_fields_path, params: {
          custom_field: { name: "Blocked", record_type: "Person", field_type: "text" }
        }
      }.not_to change(CustomField, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /settings/custom_fields/:id" do
    it "updates a field for admins" do
      patch settings_custom_field_path(field), params: {
        custom_field: { name: "Tier", field_type: "select", options_text: "Bronze\nGold", required: true }
      }

      expect(response).to redirect_to(settings_custom_fields_path)
      expect(field.reload.name).to eq("Tier")
      expect(field.options).to eq(%w[Bronze Gold])
    end
  end

  describe "DELETE /settings/custom_fields/:id" do
    it "removes a field for admins" do
      expect {
        delete settings_custom_field_path(field)
      }.to change(CustomField, :count).by(-1)

      expect(response).to redirect_to(settings_custom_fields_path)
    end
  end
end
