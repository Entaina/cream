# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sidebar navigation", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }

  def sign_in_and_switch(user)
    sign_in_as(user)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "grouped menu structure" do
    it "shows daily items and collapsible groups for admins" do
      sign_in_and_switch(admin)

      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Marketing")
      expect(response.body).to include("Configuración")
      expect(response.body).to include("Mi perfil")
      expect(response.body).to include("Mis listas")
      expect(response.body).not_to include("Mail merge")
      expect(response.body).not_to include('data-key="mail_merge"')
    end

    it "hides the entire configuration group from non-admins" do
      sign_in_and_switch(member)

      get root_path

      expect(response.body).not_to include("Configuración")
      expect(response.body).not_to include(settings_workspace_path)
      expect(response.body).not_to include(pipelines_path)
      expect(response.body).not_to include(products_path)
      expect(response.body).to include("Mi perfil")
      expect(response.body).to include("Marketing")
    end

    it "shows workspace settings inside the configuration group for admins" do
      sign_in_and_switch(admin)

      get root_path

      expect(response.body).to include(settings_workspace_path)
    end
  end

  describe "mail merge removal" do
    it "redirects mail merge routes because the feature is disabled" do
      sign_in_and_switch(admin)

      get new_mail_merge_path

      expect(response).to redirect_to(root_path)
    end
  end
end
