require "rails_helper"

RSpec.describe "Imports", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:csv_import_export).and_return(true)
    sign_in_as(admin)
  end

  it "imports people from an uploaded CSV" do
    csv = <<~CSV
      first_name,last_name,email,company
      Import,User,imported@example.com,Import Co
    CSV
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "people.csv")

    expect {
      post import_path, params: {record_type: "Person", file: file}
    }.to change { workspace.people.where(email: "imported@example.com").count }.by(1)

    expect(response).to redirect_to(people_path)
  end
end
