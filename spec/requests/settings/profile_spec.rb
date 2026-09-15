require "rails_helper"

RSpec.describe "Settings::Profile", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let(:membership) { memberships(:one_one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }

  before do
    workspace.update!(sales_director_enabled: true)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:sales_director).and_return(true)
    allow(Ai::Configuration).to receive(:configured?).and_return(true)
  end

  describe "GET /settings/profile" do
    it "shows personal data and the sales director preference for admins" do
      sign_in_as(admin)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      get settings_profile_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Datos personales")
      expect(response.body).to include("Idioma")
      expect(response.body).to include(admin.name)
      expect(response.body).to include(admin.email_address)
      expect(response.body).to include("Mostrar briefing del director de ventas en el dashboard")
    end

    it "shows the sales director preference for members" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      get settings_profile_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Mostrar briefing del director de ventas en el dashboard")
    end

    it "still shows the pipeline preference when sales director is disabled" do
      workspace.update!(sales_director_enabled: false)
      sign_in_as(admin)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      get settings_profile_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Mostrar briefing del director de ventas en el dashboard")
      expect(response.body).to include("Pipeline predeterminado")
      expect(response.body).to include(pipeline.name)
    end
  end

  describe "PATCH /settings/profile" do
    it "allows users to update their name" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      patch settings_profile_path, params: {user: {name: "Nuevo Nombre"}}

      expect(response).to redirect_to(settings_profile_path)
      expect(flash[:notice]).to eq(I18n.t("profile.flashes.name_updated"))
      expect(member.reload.name).to eq("Nuevo Nombre")
    end

    it "allows users to update their locale" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}
      member.update!(locale: "es")

      patch settings_profile_path, params: {user: {name: member.name, locale: "en"}}

      expect(response).to redirect_to(settings_profile_path)
      expect(flash[:notice]).to eq(I18n.t("profile.flashes.name_updated"))
      expect(member.reload.locale).to eq("en")
      expect(cookies[:locale]).to eq("en")
    end

    it "rejects a blank name" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}
      original_name = member.name

      patch settings_profile_path, params: {user: {name: ""}}

      expect(response).to redirect_to(settings_profile_path)
      expect(flash[:alert]).to be_present
      expect(member.reload.name).to eq(original_name)
    end

    it "allows members to disable the sales director briefing" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      patch settings_profile_path, params: {membership: {sales_director_briefing_enabled: false}}

      expect(response).to redirect_to(settings_profile_path)
      expect(memberships(:one_member).reload.sales_director_briefing_enabled?).to be(false)
    end

    it "allows admins to update their own preference" do
      sign_in_as(admin)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      patch settings_profile_path, params: {membership: {sales_director_briefing_enabled: false}}

      expect(response).to redirect_to(settings_profile_path)
      expect(membership.reload.sales_director_briefing_enabled?).to be(false)
    end

    it "allows users to choose their default pipeline for the workspace" do
      other_pipeline = pipeline.duplicate(name: "Partners").tap(&:save!)
      sign_in_as(admin)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      patch settings_profile_path, params: {membership: {current_pipeline_id: other_pipeline.id}}

      expect(response).to redirect_to(settings_profile_path)
      expect(membership.reload.current_pipeline).to eq(other_pipeline)
    end

    it "rejects a default pipeline from another workspace" do
      foreign_pipeline = Pipeline.create_default!(workspaces(:two))
      sign_in_as(admin)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      patch settings_profile_path, params: {membership: {current_pipeline_id: foreign_pipeline.id}}

      expect(response).to redirect_to(settings_profile_path)
      expect(membership.reload.current_pipeline).not_to eq(foreign_pipeline)
    end
  end
end
