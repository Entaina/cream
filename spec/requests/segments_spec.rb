require "rails_helper"

RSpec.describe "Segments", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_segments).and_return(true)
    sign_in_as(admin)
  end

  it "lists segments" do
    workspace.segments.create!(name: "Everyone", record_type: "Person", user: admin, filters: {})

    get segments_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Everyone")
  end

  it "creates a segment and shows resolved members" do
    person = create_person!(workspace, company: companies(:acme), email: "seg@acme.com")

    expect {
      post segments_path, params: {
        segment: {name: "Acme people", record_type: "Person", filters: {company_id: companies(:acme).id}}
      }
    }.to change(Segment, :count).by(1)

    segment = Segment.last
    expect(response).to redirect_to(segment_path(segment))

    get segment_path(segment)
    expect(response).to have_http_status(:success)
    expect(response.body).to include(person.display_name)
  end

  it "forbids non-admin members from creating segments" do
    sign_in_as(salesperson)
    patch switch_workspace_path, params: {workspace_id: workspace.id}

    expect {
      post segments_path, params: {
        segment: {name: "Blocked", record_type: "Person", filters: {}}
      }
    }.not_to change(Segment, :count)

    expect(response).to redirect_to(root_path)
  end
end
