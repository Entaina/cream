require "rails_helper"

RSpec.describe Workspace, type: :model do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "validates slug format and uniqueness" do
    duplicate = described_class.new(name: "Copy", slug: workspace.slug, time_zone: "Europe/Madrid")
    expect(duplicate).not_to be_valid

    invalid = described_class.new(name: "Bad", slug: "Bad Slug", time_zone: "Europe/Madrid")
    expect(invalid).not_to be_valid
  end

  it "reports okm configuration" do
    expect(workspace.okm_configured?).to be false

    workspace.update!(
      okm_drive_id: "drive-1",
      okm_service_account_key: {
        client_email: "bot@test.iam.gserviceaccount.com",
        private_key: "-----BEGIN PRIVATE KEY-----\nx\n-----END PRIVATE KEY-----\n"
      }.to_json
    )

    expect(workspace.okm_configured?).to be true
    expect(workspace.okm_service_account_client_email).to eq("bot@test.iam.gserviceaccount.com")
  end

  it "rejects mail_from_name with newlines" do
    workspace.mail_from_name = "Bad\nName"

    expect(workspace).not_to be_valid
    expect(workspace.errors[:mail_from_name]).to be_present
  end

  it "strips mail_from_name" do
    workspace.update!(mail_from_name: "  Entaina  ")

    expect(workspace.mail_from_name).to eq("Entaina")
  end
end
