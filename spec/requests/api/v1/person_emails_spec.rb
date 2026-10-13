require "rails_helper"

RSpec.describe "Api::V1::PersonEmails", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "lead@example.com") }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }

  let(:valid_params) do
    {
      email: {
        to_address: "lead@example.com",
        subject: "Welcome",
        body: "Thanks for your interest."
      }
    }
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
  end

  describe "POST /api/v1/people/:person_id/emails" do
    context "when Gmail sending is not available" do
      before do
        allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)
      end

      it "creates the message on the person and enqueues SMTP delivery" do
        expect {
          post "/api/v1/people/#{person.id}/emails", params: valid_params, headers: headers
        }.to change(EmailMessage, :count).by(1)
          .and have_enqueued_mail(RecordMailer, :tracked_email)
          .and change { person.activities.where(action: "email_sent").count }.by(1)

        message = EmailMessage.order(:id).last
        expect(response).to have_http_status(:created)
        expect(message.record).to eq(person)
        expect(response.parsed_body).to include("id" => message.id, "via_gmail" => false)
      end
    end

    it "defaults the recipient to the person's email when to_address is omitted" do
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)

      post "/api/v1/people/#{person.id}/emails",
        params: {email: {subject: "Hi", body: "Hello"}},
        headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["to_address"]).to eq("lead@example.com")
    end

    it "does not allow emailing a person from another workspace" do
      foreign = create_person!(workspaces(:two))

      expect {
        post "/api/v1/people/#{foreign.id}/emails", params: valid_params, headers: headers
      }.not_to change(EmailMessage, :count)

      expect(response).to have_http_status(:not_found)
    end

    context "when record_email is disabled" do
      before do
        allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(false)
      end

      it "returns not found" do
        expect {
          post "/api/v1/people/#{person.id}/emails", params: valid_params, headers: headers
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
