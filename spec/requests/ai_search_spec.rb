require "rails_helper"

RSpec.describe "AiSearch", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    sign_in_as(user)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:ai_assistant).and_return(true)
  end

  it "renders natural-language search results" do
    person = create_person!(workspace, company: companies(:acme))
    person.tasks.create!(title: "Late", due_on: Date.current - 1, workspace: workspace, user: user, assignee: user)

    get ai_search_path, params: {q: "overdue tasks"}

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Late")
    expect(response.body).to include("Pending tasks")
  end
end
