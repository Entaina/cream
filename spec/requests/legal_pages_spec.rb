require "rails_helper"

RSpec.describe "Legal pages", type: :request do
  describe "GET /terms" do
    it "renders without authentication" do
      get terms_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Términos y condiciones")
    end
  end

  describe "GET /privacy" do
    it "renders without authentication" do
      get privacy_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Política de privacidad")
    end
  end

  describe "GET /support" do
    it "renders without authentication" do
      get support_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Asistencia")
      expect(response.body).to include("support@example.com")
    end
  end
end
