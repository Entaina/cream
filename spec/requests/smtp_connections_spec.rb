require "rails_helper"

RSpec.describe "SMTP connections", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:member) { users(:two) }

  def connection_params(**overrides)
    {
      smtp_connection: {
        address: "smtp.example.com",
        port: 587,
        user_name: "smtp-user",
        password: "smtp-secret-yyyy",
        from_email: "noreply@example.com",
        from_name: "Cream",
        authentication: "plain",
        enable_starttls_auto: "1"
      }.merge(overrides)
    }
  end

  describe "GET /settings/workspace" do
    it "shows the SMTP form without echoing the stored password" do
      workspace.create_smtp_connection!(
        user: admin,
        address: "smtp.example.com",
        user_name: "smtp-user",
        password: "supersecretpassword",
        from_email: "noreply@example.com"
      )
      sign_in_as(admin)

      get settings_workspace_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SMTP")
      expect(response.body).to include("smtp.example.com")
      expect(response.body).not_to include("supersecretpassword")
      expect(response.body).to include("supe…word")
    end
  end

  describe "POST /smtp_connection" do
    it "creates the connection for admins" do
      sign_in_as(admin)

      expect {
        post smtp_connection_path, params: connection_params
      }.to change(SmtpConnection, :count).by(1)

      expect(response).to redirect_to(settings_workspace_path)
      connection = workspace.reload.smtp_connection
      expect(connection.address).to eq("smtp.example.com")
      expect(connection.password).to eq("smtp-secret-yyyy")
      expect(connection.from_email).to eq("noreply@example.com")
      expect(connection.user).to eq(admin)
      expect(connection.enable_starttls_auto).to be(true)
    end

    it "is admin-only" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      expect {
        post smtp_connection_path, params: connection_params
      }.not_to change(SmtpConnection, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /smtp_connection" do
    it "keeps the stored password when the field comes back blank" do
      workspace.create_smtp_connection!(
        user: admin,
        address: "smtp.example.com",
        user_name: "smtp-user",
        password: "keep-secret-5678",
        from_email: "old@example.com"
      )
      sign_in_as(admin)

      patch smtp_connection_path, params: connection_params(
        password: "",
        from_email: "new@example.com",
        from_name: "Nuevo",
        sender_domain_validated: "1"
      )

      connection = workspace.reload.smtp_connection
      expect(connection.password).to eq("keep-secret-5678")
      expect(connection.from_email).to eq("new@example.com")
      expect(connection.from_name).to eq("Nuevo")
      expect(connection.sender_domain_validated).to be(true)
    end
  end

  describe "DELETE /smtp_connection" do
    it "removes the connection" do
      workspace.create_smtp_connection!(
        user: admin,
        address: "smtp.example.com",
        password: "smtp-secret-yyyy",
        from_email: "noreply@example.com"
      )
      sign_in_as(admin)

      delete smtp_connection_path

      expect(response).to redirect_to(settings_workspace_path)
      expect(workspace.reload.smtp_connection).to be_nil
    end
  end
end
