require "rails_helper"

RSpec.describe ApiToken, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }

  it "defaults to a write token that expires in 90 days" do
    token = user.api_tokens.create!(name: "Default", workspace: workspace)

    expect(token).to have_attributes(token_scope: "write", read_only?: false)
    expect(token.expires_at).to be_within(1.minute).of(90.days.from_now)
    expect(described_class.authenticate(token.plaintext_token)).to eq(token)
  end

  it "requires an expiry on new tokens" do
    expect(user.api_tokens.build(name: "Forever", workspace: workspace, expires_at: nil)).not_to be_valid
  end

  it "keeps authenticating tokens created before expiry was required" do
    token = user.api_tokens.create!(name: "Legacy", workspace: workspace)
    token.update_columns(expires_at: nil)

    expect(described_class.authenticate(token.plaintext_token)).to eq(token)
    expect(token.reload).to be_valid
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
