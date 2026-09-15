require "rails_helper"

RSpec.describe Comment, type: :model do
  fixtures :users, :workspaces, :memberships

  it "creates mention notifications" do
    workspace = workspaces(:one)
    person = create_person!(workspace)
    author = users(:one)
    users(:two)

    expect {
      Comment.create!(
        workspace: workspace,
        commentable: person,
        user: author,
        body: "Hey @two please review"
      )
    }.to change(Notification, :count).by(1)
  end
end
