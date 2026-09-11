require "rails_helper"

RSpec.describe "Locale preferences", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }

  describe "PATCH /locale_preference" do
    User::LOCALES.each do |locale|
      it "persists the #{locale} locale for the current user" do
        sign_in_as(member)

        patch locale_preference_path, params: { locale: locale }, as: :json

        expect(response).to have_http_status(:ok)
        expect(member.reload.locale).to eq(locale)
        expect(cookies[:locale]).to eq(locale)
      end
    end

    it "sets the guest cookie without authentication" do
      patch locale_preference_path, params: { locale: "en" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(cookies[:locale]).to eq("en")
    end

    it "rejects unknown locales" do
      sign_in_as(member)
      member.update!(locale: "es")

      patch locale_preference_path, params: { locale: "fr" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(member.reload.locale).to eq("es")
    end
  end

  describe "layout and navigation" do
    it "renders the html lang attribute from the user locale" do
      sign_in_as(member)
      member.update!(locale: "en")

      get root_path

      expect(response.body).to include('lang="en"')
    end

    it "renders Spanish sidebar labels by default" do
      sign_in_as(member)

      get root_path

      expect(response.body).to include("Buscar...")
      expect(response.body).to include("Personas")
    end

    it "renders English sidebar labels when the user locale is en" do
      sign_in_as(member)
      member.update!(locale: "en")

      get root_path

      expect(response.body).to include("Search...")
      expect(response.body).to include("People")
    end
  end

  describe "session persistence" do
    let(:workspace) { workspaces(:one) }

    it "restores the profile locale after signing in again" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }
      member.update!(locale: "es")

      patch settings_profile_path, params: { user: { name: member.name, locale: "en" } }
      expect(member.reload.locale).to eq("en")

      delete session_path
      cookies.delete(:locale)

      post session_path, params: { email_address: member.email_address, password: "password" }
      follow_redirect!

      expect(response.body).to include("Search...")
      expect(response.body).to include('lang="en"')
    end

    it "keeps the profile locale on the login page after signing out" do
      sign_in_as(member)
      member.update!(locale: "en")

      delete session_path

      get new_session_path

      expect(response.body).to include("Sign in")
      expect(response.body).to include('lang="en"')
      expect(cookies[:locale]).to eq("en")
    end
  end

  describe "guest login page" do
    it "renders Spanish copy by default" do
      get new_session_path

      expect(response.body).to include("Iniciar sesión")
      expect(response.body).to include('lang="es"')
    end

    it "renders English copy when the guest cookie is en" do
      cookies[:locale] = "en"

      get new_session_path

      expect(response.body).to include("Sign in")
      expect(response.body).to include('lang="en"')
    end
  end
end
