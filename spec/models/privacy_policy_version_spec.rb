require "rails_helper"

RSpec.describe PrivacyPolicyVersion do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "requires unique content_hash per workspace" do
    described_class.create!(
      workspace: workspace,
      content_hash: "abc123",
      policy_path: PrivacyPolicyVersion::POLICY_PATH,
      policy_content: "<p>Policy</p>",
      statement_content: "<p>Statement</p>"
    )

    duplicate = described_class.new(
      workspace: workspace,
      content_hash: "abc123",
      policy_path: PrivacyPolicyVersion::POLICY_PATH,
      policy_content: "<p>Other</p>",
      statement_content: "<p>Other</p>"
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:content_hash]).to be_present
  end

  it "does not allow changing immutable content" do
    version = described_class.create!(
      workspace: workspace,
      content_hash: "abc123",
      policy_path: PrivacyPolicyVersion::POLICY_PATH,
      policy_content: "<p>Policy</p>",
      statement_content: "<p>Statement</p>"
    )

    version.policy_content = "<p>Changed</p>"

    expect(version).not_to be_valid
    expect(version.errors[:policy_content]).to be_present
  end
end
