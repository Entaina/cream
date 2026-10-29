require "rails_helper"
require "rake"

RSpec.describe "superadmin:prune_support_memberships" do
  let(:task) { Rake::Task["superadmin:prune_support_memberships"] }
  let(:workspace) { Workspace.create!(name: "Client") }
  let(:former) { User.create!(name: "Former", email_address: "former@example.com", password: "password") }
  let(:current) { User.create!(name: "Current", email_address: "current@example.com", password: "password", superadmin: true) }
  let(:member) { User.create!(name: "Member", email_address: "member@example.com", password: "password") }

  before(:all) do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    load Rails.root.join("lib/tasks/superadmin.rake").to_s unless Rake::Task.task_defined?("superadmin:prune_support_memberships")
  end

  after { task.reenable }

  it "removes support memberships of users who are no longer superadmin" do
    workspace.memberships.create!(user: member, role: "admin")
    stale = workspace.memberships.create!(user: former, role: "admin", superadmin_access: true)
    kept = workspace.memberships.create!(user: current, role: "admin", superadmin_access: true)

    expect { task.invoke }.to output(/Removed 1 support memberships/).to_stdout

    expect(Membership.exists?(stale.id)).to be(false)
    expect(Membership.exists?(kept.id)).to be(true)
    expect(workspace.memberships.real_team.map(&:user)).to eq([member])
  end
end
