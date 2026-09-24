require "rails_helper"

RSpec.describe "ListEntries", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:list) { workspace.lists.create!(name: "Prospects", record_type: "Person") }
  let(:person) { create_person!(workspace, company: companies(:acme)) }

  before { sign_in_as(member) }

  it "adds and removes a person from a list" do
    expect {
      post list_entries_path(list), params: {record_id: person.id}
    }.to change(ListEntry, :count).by(1)

    entry = list.list_entries.sole
    expect(response).to redirect_to(list_path(list))

    expect {
      delete list_entry_path(list, entry)
    }.to change(ListEntry, :count).by(-1)
  end
end
