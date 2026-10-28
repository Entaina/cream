require "rails_helper"

RSpec.describe ApiToken, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }

  it "defaults to a write token that never expires" do
    token = user.api_tokens.create!(name: "Default", workspace: workspace)

    expect(token).to have_attributes(token_scope: "write", expires_at: nil, read_only?: false)
    expect(described_class.authenticate(token.plaintext_token)).to eq(token)
  end

  it "authenticates tokens until they expire" do
    token = user.api_tokens.create!(name: "Short", workspace: workspace, expires_at: 1.hour.from_now)

    expect(described_class.authenticate(token.plaintext_token)).to eq(token)

    travel_to(2.hours.from_now) do
      expect(described_class.authenticate(token.plaintext_token)).to be_nil
    end
  end

  it "marks read tokens as read only" do
    expect(user.api_tokens.create!(name: "Reader", workspace: workspace, token_scope: "read")).to be_read_only
  end

  it "rejects unknown scopes" do
    expect(user.api_tokens.build(name: "Bad", workspace: workspace, token_scope: "admin")).not_to be_valid
  end
end
