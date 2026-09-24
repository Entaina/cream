require "rails_helper"

RSpec.describe "Notes", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:person) { create_person!(workspaces(:one), company: companies(:acme)) }

  before { sign_in_as(member) }

  it "creates, updates, and deletes a note on a person" do
    expect {
      post notes_path, params: {
        notable_type: "Person",
        notable_id: person.id,
        note: {title: "Call", body: "Follow up next week"}
      }
    }.to change(Note, :count).by(1)

    note = Note.last
    expect(response).to redirect_to(person_path(person))

    patch note_path(note), params: {note: {body: "Follow up tomorrow"}}
    expect(response).to redirect_to(person_path(person))
    expect(note.reload.body).to eq("Follow up tomorrow")

    expect {
      delete note_path(note)
    }.to change(Note, :count).by(-1)
  end
end
