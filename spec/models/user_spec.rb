require "rails_helper"

RSpec.describe User, type: :model do
  it "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    expect(user.email_address).to eq("downcased@example.com")
  end

  describe "theme" do
    it "defaults to system" do
      user = User.create!(name: "Theme User", email_address: "theme@example.com", password: "password")

      expect(user.theme).to eq("system")
    end

    it "rejects values outside THEMES" do
      user = User.new(name: "Theme User", email_address: "theme2@example.com", password: "password", theme: "purple")

      expect(user).not_to be_valid
      expect(user.errors[:theme]).to be_present
    end
  end

  describe "locale" do
    it "defaults to es" do
      user = User.create!(name: "Locale User", email_address: "locale@example.com", password: "password")

      expect(user.locale).to eq("es")
    end

    it "rejects values outside LOCALES" do
      user = User.new(name: "Locale User", email_address: "locale2@example.com", password: "password", locale: "fr")

      expect(user).not_to be_valid
      expect(user.errors[:locale]).to be_present
    end
  end

  describe "#active_workspace" do
    fixtures :users, :workspaces, :memberships

    let(:user) { users(:one) }

    it "returns the session workspace when the user belongs to it" do
      workspace = workspaces(:two)
      Membership.create!(user: user, workspace: workspace, role: "salesperson")

      expect(user.active_workspace(session_workspace_id: workspace.id)).to eq(workspace)
    end

    it "falls back to the default workspace when the session workspace is invalid" do
      expect(user.active_workspace(session_workspace_id: 0)).to eq(user.default_workspace)
    end
  end

  describe "#sidebar_prefs" do
    it "returns default order when no preferences are saved" do
      user = User.create!(name: "Prefs User", email_address: "prefs@example.com", password: "password")

      expect(user.sidebar_order).to eq(User.sidebar_default_keys)
      expect(user.sidebar_hidden).to eq([])
    end

    it "merges saved order with newly added default keys" do
      user = User.create!(name: "Prefs User", email_address: "prefs2@example.com", password: "password")
      user.update!(sidebar_prefs: { "order" => %w[tasks dashboard], "hidden" => %w[api_tokens] })

      expect(user.sidebar_order.first(2)).to eq(%w[tasks dashboard])
      expect(user.sidebar_order).to include(*User.sidebar_default_keys)
      expect(user.sidebar_hidden).to eq(%w[api_tokens])
    end

    it "drops orphan keys such as mail_merge when merging order" do
      user = User.create!(name: "Prefs User", email_address: "prefs4@example.com", password: "password")
      user.update!(sidebar_prefs: { "order" => %w[mail_merge tasks dashboard], "hidden" => %w[mail_merge] })

      expect(user.sidebar_order).not_to include("mail_merge")
      expect(user.sidebar_hidden).not_to include("mail_merge")
      expect(user.sidebar_order.first(2)).to eq(%w[tasks dashboard])
    end

    it "excludes settings keys for non-admin users" do
      user = User.create!(name: "Prefs User", email_address: "prefs5@example.com", password: "password")

      expect(user.sidebar_default_keys(admin: false)).not_to include("products", "workspace")
      expect(user.sidebar_default_keys(admin: true)).to include("products", "workspace")
    end

    it "updates preferences with validated keys" do
      user = User.create!(name: "Prefs User", email_address: "prefs3@example.com", password: "password")

      user.update_sidebar_prefs!(order: %w[deals dashboard], hidden: %w[team])

      expect(user.sidebar_order.first(2)).to eq(%w[deals dashboard])
      expect(user.sidebar_hidden).to eq(%w[team])
    end
  end

  describe ".provision_default_workspace!" do
    around do |example|
      original_domain = ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"]
      original_name = ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"]
      ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"] = "example.com"
      ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"] = "Example"
      example.run
    ensure
      ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"] = original_domain
      ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"] = original_name
    end

    it "creates a personal workspace for external emails" do
      user = User.create!(name: "Jane Doe", email_address: "jane@external.com", password: "password")

      expect {
        described_class.provision_default_workspace!(user, workspace_name: "Acme Inc")
      }.to change(Workspace, :count).by(1)
        .and change(Membership, :count).by(1)

      membership = user.memberships.last
      expect(membership.role).to eq("admin")
      expect(membership.workspace.name).to eq("Acme Inc")
    end

    it "joins the organization workspace for matching email domains" do
      org = Workspace.create!(name: "Example", slug: "example")
      org.memberships.create!(user: User.create!(name: "Admin", email_address: "admin@example.com", password: "password"), role: "admin")
      user = User.create!(name: "Ana Example", email_address: "member@example.com", password: "password")

      expect {
        described_class.provision_default_workspace!(user, workspace_name: "Ignored")
      }.not_to change(Workspace, :count)

      membership = user.memberships.last
      expect(membership.workspace).to eq(org)
      expect(membership.role).to eq("salesperson")
    end

    it "creates the organization workspace for the first matching user" do
      user = User.create!(name: "First User", email_address: "first@example.com", password: "password")

      expect {
        described_class.provision_default_workspace!(user)
      }.to change(Workspace, :count).by(1)

      membership = user.memberships.last
      expect(membership.workspace.slug).to eq("example")
      expect(membership.workspace.name).to eq("Example")
      expect(membership.role).to eq("admin")
    end

    it "creates a personal workspace when organization env vars are not set" do
      ENV.delete("CREAM_ORGANIZATION_EMAIL_DOMAIN")
      ENV.delete("CREAM_ORGANIZATION_WORKSPACE_NAME")

      user = User.create!(name: "Ana Example", email_address: "other@example.com", password: "password")

      expect {
        described_class.provision_default_workspace!(user)
      }.to change(Workspace, :count).by(1)

      expect(user.memberships.last.workspace.name).to eq("Ana Example's Workspace")
    end

    it "joins the demo workspace as member when it exists" do
      demo = Workspace.create!(name: "Cream Demo", slug: "cream-demo")
      user = User.create!(name: "Jane Doe", email_address: "jane@example.com", password: "password")

      expect {
        described_class.provision_default_workspace!(user, workspace_name: "Acme Inc")
      }.to change(Membership, :count).by(2)

      demo_membership = user.memberships.find_by!(workspace: demo)
      expect(demo_membership.role).to eq("salesperson")
    end

    it "does not create the demo workspace when it is missing" do
      user = User.create!(name: "Jane Doe", email_address: "jane@example.com", password: "password")

      expect {
        described_class.provision_default_workspace!(user, workspace_name: "Acme Inc")
      }.to change(Workspace, :count).by(1)
        .and change(Membership, :count).by(1)
    end
  end
end
