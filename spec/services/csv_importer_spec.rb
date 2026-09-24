require "rails_helper"

RSpec.describe CsvImporter do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  it "creates people from valid rows" do
    csv = <<~CSV
      first_name,last_name,email,company
      Ada,Lovelace,ada@example.com,Analytical Engines
    CSV

    result = described_class.import("Person", workspace: workspace, user: user, io: StringIO.new(csv))

    expect(result.created).to eq(1)
    expect(result.errors).to be_empty
    expect(workspace.people.find_by(email: "ada@example.com")).to be_present
  end

  it "records validation errors without aborting the batch" do
    csv = <<~CSV
      first_name,last_name,email,company
      ,,bad-email,Co
      Grace,Hopper,grace@example.com,US Navy
    CSV

    result = described_class.import("Person", workspace: workspace, user: user, io: StringIO.new(csv))

    expect(result.created).to eq(1)
    expect(result.errors.first).to match(/Line 2/)
    expect(workspace.people.find_by(email: "grace@example.com")).to be_present
  end
end
