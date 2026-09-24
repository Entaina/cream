require "rails_helper"

RSpec.describe "RecordAttachments", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:attachments).and_return(true)
    sign_in_as(member)
  end

  it "uploads and removes an attachment on a company" do
    file = Rack::Test::UploadedFile.new(StringIO.new("hello"), "text/plain", original_filename: "brief.txt")

    expect {
      post record_attachments_path, params: {
        attachable_type: "Company",
        attachable_id: company.id,
        record_attachment: {file: file, name: "Brief"}
      }
    }.to change(RecordAttachment, :count).by(1)

    attachment = RecordAttachment.last
    expect(response).to redirect_to(company_path(company))

    expect {
      delete record_attachment_path(attachment)
    }.to change(RecordAttachment, :count).by(-1)
  end
end
