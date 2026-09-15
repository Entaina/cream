require "rails_helper"

RSpec.describe "Comments", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:person) { create_person!(workspaces(:one)) }

  it "creates a comment on a person" do
    sign_in_as(member)

    expect {
      post comments_path, params: {
        commentable_type: "Person",
        commentable_id: person.id,
        comment: {body: "Looks good"}
      }
    }.to change(Comment, :count).by(1)

    expect(response).to redirect_to(person_path(person))
  end
end
