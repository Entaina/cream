require "rails_helper"

RSpec.describe NotificationPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:recipient) { users(:one) }
  let(:other_member) { users(:two) }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  let(:notification) do
    workspace.notifications.create!(
      user: recipient,
      kind: "mention",
      title: "Hi",
      body: "Body"
    )
  end

  it "allows the recipient to update their notification" do
    policy = described_class.new(context_for(recipient), notification)
    expect(policy.update?).to be true
  end

  it "forbids another member from updating someone else's notification" do
    policy = described_class.new(context_for(other_member), notification)
    expect(policy.update?).to be false
  end

  it "allows members to list and mark all read" do
    policy = described_class.new(context_for(recipient), notification)
    expect(policy.index?).to be true
    expect(policy.mark_all_read?).to be true
  end

  describe "Scope" do
    let!(:mine) { notification }
    let!(:theirs) do
      workspace.notifications.create!(user: other_member, kind: "mention", title: "Other", body: "X")
    end

    it "returns only the current user's notifications" do
      scope = described_class::Scope.new(context_for(recipient), Notification.all).resolve
      expect(scope).to contain_exactly(mine)
    end
  end
end
