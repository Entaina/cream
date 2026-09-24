require "rails_helper"

RSpec.describe EmailTemplatePolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:author) { users(:two) }
  let(:other_member) { users(:three) }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  let(:template) do
    workspace.email_templates.create!(name: "T1", subject: "S", body: "<p>B</p>", user: author)
  end

  it "allows any member to preview" do
    policy = described_class.new(context_for(other_member), template)
    expect(policy.preview?).to be true
  end

  it "allows the author to update and destroy" do
    policy = described_class.new(context_for(author), template)
    expect(policy.update?).to be true
    expect(policy.destroy?).to be true
  end

  it "allows admin to update and destroy any template" do
    policy = described_class.new(context_for(admin), template)
    expect(policy.update?).to be true
    expect(policy.destroy?).to be true
  end

  it "forbids another member from updating someone else's template" do
    policy = described_class.new(context_for(other_member), template)
    expect(policy.update?).to be false
    expect(policy.destroy?).to be false
  end
end
