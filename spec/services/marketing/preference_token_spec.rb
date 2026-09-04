require "rails_helper"

RSpec.describe Marketing::PreferenceToken do
  fixtures :users, :workspaces, :memberships

  let(:person) { create_person!(workspaces(:one), email: "token@example.com") }

  it "generates and verifies a token for the person" do
    token = described_class.generate(person: person)

    expect(described_class.verify(token)).to eq(person)
  end

  it "returns nil for invalid tokens" do
    expect(described_class.verify("invalid")).to be_nil
  end
end
