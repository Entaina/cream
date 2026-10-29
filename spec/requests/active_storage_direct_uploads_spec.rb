require "rails_helper"

RSpec.describe "Active Storage direct uploads", type: :request do
  it "rejects unauthenticated direct upload requests" do
    expect {
      post "/rails/active_storage/direct_uploads", params: {
        blob: {
          filename: "note.txt",
          content_type: "text/plain",
          byte_size: 4,
          checksum: Base64.strict_encode64(Digest::MD5.digest("test"))
        }
      }
    }.not_to change(ActiveStorage::Blob, :count)

    expect(response).to have_http_status(:not_found)
  end
end
