require "rails_helper"

RSpec.describe Marketing::ConsentPolicySnapshot do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "reuses the same version for identical content" do
    first = described_class.capture(
      workspace: workspace,
      policy_html: "<p>Policy A</p>",
      statement_html: "<p>Statement A</p>"
    )
    second = described_class.capture(
      workspace: workspace,
      policy_html: "<p>Policy A</p>",
      statement_html: "<p>Statement A</p>"
    )

    expect(second.id).to eq(first.id)
    expect(PrivacyPolicyVersion.count).to eq(1)
  end

  it "creates a new version when policy content changes" do
    first = described_class.capture(
      workspace: workspace,
      policy_html: "<p>Policy A</p>",
      statement_html: "<p>Statement A</p>"
    )
    second = described_class.capture(
      workspace: workspace,
      policy_html: "<p>Policy B</p>",
      statement_html: "<p>Statement A</p>"
    )

    expect(second.id).not_to eq(first.id)
    expect(PrivacyPolicyVersion.count).to eq(2)
  end

  it "normalizes whitespace when computing digest" do
    digest_one = described_class.digest(
      policy_html: "<p>Policy   A</p>",
      statement_html: "<p>Statement\nA</p>"
    )
    digest_two = described_class.digest(
      policy_html: "<p>Policy A</p>",
      statement_html: "<p>Statement A</p>"
    )

    expect(digest_one).to eq(digest_two)
  end
end
