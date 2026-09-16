require "rails_helper"

RSpec.describe "Mailjet connections", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:member) { users(:two) }

  def connection_params(**overrides)
    {
      mailjet_connection: {
        api_key: "public-api-key-xxxx",
        secret_key: "private-secret-yyyy",
        from_email: "noreply@example.com",
        from_name: "Cream"
      }.merge(overrides)
    }
  end

  before do
    allow(Marketing::Esp::MailjetWebhookRegistrar).to receive(:sync!)
    allow(Marketing::Esp::MailjetWebhookRegistrar).to receive(:remove!)
  end

  describe "GET /settings/workspace" do
    it "shows the Mailjet form without echoing stored keys" do
      workspace.create_mailjet_connection!(
        user: admin,
        api_key: "supersecretapikey",
        secret_key: "supersecretsecret",
        from_email: "noreply@example.com"
      )
      sign_in_as(admin)

      get settings_workspace_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mailjet")
      expect(response.body).not_to include("supersecretapikey")
      expect(response.body).not_to include("supersecretsecret")
      expect(response.body).to include("supe…ikey")
      expect(response.body).to include("/e/events")
      expect(response.body).to include("Usar Mailjet para el correo transaccional")
    end
  end

  describe "POST /mailjet_connection" do
    it "creates the connection for admins" do
      sign_in_as(admin)

      expect {
        post mailjet_connection_path, params: connection_params
      }.to change(MailjetConnection, :count).by(1)

      expect(response).to redirect_to(settings_workspace_path)
      connection = workspace.reload.mailjet_connection
      expect(connection.api_key).to eq("public-api-key-xxxx")
      expect(connection.secret_key).to eq("private-secret-yyyy")
      expect(connection.from_email).to eq("noreply@example.com")
      expect(connection.user).to eq(admin)
      expect(connection.webhook_token).to be_present
      expect(connection.transactional_enabled?).to be(false)
      expect(Marketing::Esp::MailjetWebhookRegistrar).to have_received(:sync!).with(connection)
    end

    it "is admin-only" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      expect {
        post mailjet_connection_path, params: connection_params
      }.not_to change(MailjetConnection, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /mailjet_connection" do
    it "keeps stored keys when the fields come back blank" do
      workspace.create_mailjet_connection!(
        user: admin,
        api_key: "keep-api-key-1234",
        secret_key: "keep-secret-5678",
        from_email: "old@example.com"
      )
      sign_in_as(admin)

      patch mailjet_connection_path, params: connection_params(
        api_key: "",
        secret_key: "",
        from_email: "new@example.com",
        from_name: "Nuevo",
        transactional_enabled: "1"
      )

      connection = workspace.reload.mailjet_connection
      expect(connection.api_key).to eq("keep-api-key-1234")
      expect(connection.secret_key).to eq("keep-secret-5678")
      expect(connection.from_email).to eq("new@example.com")
      expect(connection.from_name).to eq("Nuevo")
      expect(connection.transactional_enabled?).to be(true)
    end
  end

  describe "DELETE /mailjet_connection" do
    it "removes the connection" do
      workspace.create_mailjet_connection!(
        user: admin,
        api_key: "api-key-xxxx",
        secret_key: "secret-yyyy",
        from_email: "noreply@example.com"
      )
      sign_in_as(admin)

      delete mailjet_connection_path

      expect(response).to redirect_to(settings_workspace_path)
      expect(workspace.reload.mailjet_connection).to be_nil
      expect(Marketing::Esp::MailjetWebhookRegistrar).to have_received(:remove!)
    end
  end
end
