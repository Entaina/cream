require "rails_helper"

RSpec.describe Ai::RecordContextBuilder do
  fixtures :users, :workspaces, :companies, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:company) { companies(:acme) }
  let(:person) { create_person!(workspace, company: company, email: "alex@acme.test", job_title: "CTO") }

  it "includes core record data and related content" do
    person.notes.create!(body: "Met at conference", user: user, workspace: workspace)
    person.tasks.create!(title: "Call back", due_on: Date.current + 2, user: user, assignee: user, workspace: workspace)

    context = described_class.new(record: person, user: user).to_h

    expect(context[:record_type]).to eq("Person")
    expect(context[:email]).to eq("alex@acme.test")
    expect(context[:notes].first[:body]).to include("conference")
    expect(context[:tasks].first[:title]).to eq("Call back")
    expect(context[:open_tasks]).to eq(1)
  end
end
