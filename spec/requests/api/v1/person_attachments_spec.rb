require "rails_helper"

RSpec.describe "Api::V1::PersonAttachments", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }
  let(:person) { create_person!(workspace) }

  it "attaches a Base64 file to a person" do
    expect {
      post "/api/v1/people/#{person.id}/attachments",
        params: {attachment: {filename: "contract.pdf", content: Base64.strict_encode64("%PDF-1.4 fake"),
                              content_type: "application/pdf", name: "Signed contract"}},
        as: :json, headers: headers
    }.to change(person.record_attachments, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      "name" => "Signed contract", "filename" => "contract.pdf", "content_type" => "application/pdf", "byte_size" => 13
    )
    attachment = person.record_attachments.last
    expect(attachment.user).to eq(user)
    expect(attachment.file.download).to eq("%PDF-1.4 fake")
    expect(person.activities.pluck(:action)).to include("attachment_added")
  end

  it "attaches an uploaded file (multipart)" do
    file = Rack::Test::UploadedFile.new(StringIO.new("plain text"), "text/plain", original_filename: "notes.txt")

    post "/api/v1/people/#{person.id}/attachments", params: {attachment: {file: file}}, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("name" => "notes.txt", "filename" => "notes.txt", "byte_size" => 10)
  end

  it "rejects invalid Base64 and missing content with 422" do
    post "/api/v1/people/#{person.id}/attachments",
      params: {attachment: {filename: "a.txt", content: "***"}}, as: :json, headers: headers
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/people/#{person.id}/attachments",
      params: {attachment: {filename: "a.txt"}}, as: :json, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(person.record_attachments).to be_empty
  end

  it "rejects files over the size limit" do
    stub_const("Api::RecordAttachmentBuilder::MAX_FILE_SIZE", 4)

    post "/api/v1/people/#{person.id}/attachments",
      params: {attachment: {filename: "a.txt", content: Base64.strict_encode64("12345")}}, as: :json, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"].first).to include("exceeds")
  end

  it "returns 404 for people in other workspaces" do
    other = create_person!(workspaces(:two))

    post "/api/v1/people/#{other.id}/attachments",
      params: {attachment: {filename: "a.txt", content: Base64.strict_encode64("x")}}, as: :json, headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when the attachments feature is disabled" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:attachments).and_return(false)

    post "/api/v1/people/#{person.id}/attachments",
      params: {attachment: {filename: "a.txt", content: Base64.strict_encode64("x")}}, as: :json, headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it "requires authentication" do
    post "/api/v1/people/#{person.id}/attachments", params: {attachment: {filename: "a.txt", content: "eA=="}}, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
