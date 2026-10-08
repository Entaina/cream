require "rails_helper"

RSpec.describe Workspace, type: :model do
  fixtures :workspaces

  it "normalizes email_domain" do
    workspace = Workspace.new(name: "Test", slug: "test-domain", email_domain: "@Example.COM")

    expect(workspace).to be_valid
    expect(workspace.email_domain).to eq("example.com")
  end

  it "enforces unique email_domain" do
    workspaces(:one).update!(email_domain: "one.test")
    duplicate = Workspace.new(name: "Dup", slug: "dup-ws", email_domain: "one.test")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email_domain]).to be_present
  end
end
