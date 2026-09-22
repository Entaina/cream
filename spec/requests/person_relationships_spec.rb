require "rails_helper"

RSpec.describe "Person relationships", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { create_company!(workspace) }
  let(:alice) { create_person!(workspace, company: company, first_name: "Alice") }
  let(:bob) { create_person!(workspace, company: company, first_name: "Bob") }

  before { sign_in_as(member) }

  describe "POST /people/:person_id/relationships" do
    it "creates a directed relationship from the current person" do
      expect {
        post person_relationships_path(alice), params: {
          person_relationship: {to_person_id: bob.id, relationship_type: "invited"}
        }
      }.to change(PersonRelationship, :count).by(1)

      expect(response).to redirect_to(person_path(alice))
      relationship = PersonRelationship.last
      expect(relationship.from_person).to eq(alice)
      expect(relationship.to_person).to eq(bob)
      expect(relationship.relationship_type).to eq("invited")
    end

    it "shows the inverse label on the other person's profile" do
      post person_relationships_path(alice), params: {
        person_relationship: {to_person_id: bob.id, relationship_type: "invited"}
      }

      get person_path(bob)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).to include("invitado por")
    end

    it "rejects creating a relationship with the same person" do
      post person_relationships_path(alice), params: {
        person_relationship: {to_person_id: alice.id, relationship_type: "invited"}
      }

      expect(response).to redirect_to(person_path(alice))
      expect(flash[:alert]).to include(I18n.t("activerecord.errors.messages.cannot_be_same_person"))
      expect(PersonRelationship.count).to eq(0)
    end

    it "rejects a person from another workspace" do
      other_workspace = Workspace.create!(name: "Other", slug: "other-#{SecureRandom.hex(3)}")
      outsider = create_person!(other_workspace, company: create_company!(other_workspace))

      post person_relationships_path(alice), params: {
        person_relationship: {to_person_id: outsider.id, relationship_type: "invited"}
      }

      expect(response).to have_http_status(:not_found)
      expect(PersonRelationship.count).to eq(0)
    end
  end

  describe "DELETE /people/:person_id/relationships/:id" do
    let!(:relationship) do
      PersonRelationship.create!(from_person: alice, to_person: bob, relationship_type: "invited")
    end

    it "removes the relationship from both profiles when deleted from either side" do
      delete person_relationship_path(bob, relationship)

      expect(response).to redirect_to(person_path(bob))
      expect(PersonRelationship.exists?(relationship.id)).to be(false)

      get person_path(alice)

      expect(response.body).not_to include("invitó a")
    end
  end
end
