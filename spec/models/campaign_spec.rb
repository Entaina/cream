require "rails_helper"

RSpec.describe Campaign do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  it "validates email_body_editor" do
    campaign = workspace.campaigns.new(name: "X", status: "draft", email_body_editor: "invalid")
    expect(campaign).not_to be_valid
    expect(campaign.errors[:email_body_editor]).to be_present
  end

  it "detects configured email content from inline body" do
    campaign = workspace.campaigns.create!(
      name: "X",
      status: "draft",
      email_body: "Hola"
    )
    expect(campaign.email_content_present?).to be(true)
  end

  it "detects configured email content from base template reference" do
    template = create_email_template!(workspace, user: user)
    campaign = workspace.campaigns.create!(
      name: "X",
      status: "draft",
      email_template: template
    )
    expect(campaign.email_content_present?).to be(true)
  end
end
