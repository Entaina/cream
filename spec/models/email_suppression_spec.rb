require "rails_helper"

RSpec.describe EmailSuppression, type: :model do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "suppresses and checks addresses case-insensitively" do
    described_class.suppress!(workspace: workspace, address: "Bounce@Example.com", reason: "hard_bounce")

    expect(described_class.suppressed?(workspace, "bounce@example.com")).to be true
    expect(workspace.email_suppressions.count).to eq(1)
  end
end
