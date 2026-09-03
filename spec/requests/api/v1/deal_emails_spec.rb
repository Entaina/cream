require "rails_helper"

RSpec.describe "Api::V1::DealEmails", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { { "Authorization" => "Bearer #{token.plaintext_token}" } }

  let(:valid_params) do
    {
      email: {
        to_address: "lead@example.com",
        subject: "Proposal",
        body: "Here is the proposal."
      }
    }
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
  end

  def connect_gmail!(send_enabled:)
    workspace.gmail_connections.create!(
      user: user,
      email: "me@gmail.com",
      access_token: "at",
      refresh_token: "rt",
      expires_at: 1.hour.from_now,
      send_enabled: send_enabled,
      granted_scopes: GmailConnection::SEND_SCOPE
    )
  end

  describe "POST /api/v1/deals/:deal_id/emails" do
    context "when Gmail sending is enabled" do
      before do
        allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(true)
        connect_gmail!(send_enabled: true)
      end

      it "creates the message and enqueues Gmail delivery" do
        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: valid_params, headers: headers
        }.to change(EmailMessage, :count).by(1)
          .and have_enqueued_job(SendViaGmailJob)

        message = EmailMessage.order(:id).last
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include(
          "id" => message.id,
          "to_address" => "lead@example.com",
          "subject" => "Proposal",
          "status" => "sent",
          "via_gmail" => true
        )
        expect(message.record).to eq(deal)
        expect(message.user).to eq(user)
      end
    end

    context "when Gmail sending is not available" do
      before do
        allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)
      end

      it "creates the message and enqueues SMTP delivery" do
        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: valid_params, headers: headers
        }.to change(EmailMessage, :count).by(1)
          .and have_enqueued_mail(RecordMailer, :tracked_email)
          .and change { deal.activities.where(action: "email_sent").count }.by(1)

        message = EmailMessage.order(:id).last
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include(
          "id" => message.id,
          "via_gmail" => false
        )
      end
    end

    it "defaults the recipient to the deal's first contact when to_address is omitted" do
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company, email: "contact@example.com")
      deal_with_contact = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ contact ])

      post "/api/v1/deals/#{deal_with_contact.id}/emails",
        params: { email: { subject: "Hi", body: "Hello" } },
        headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["to_address"]).to eq("contact@example.com")
    end

    it "returns validation errors for invalid email params" do
      expect {
        post "/api/v1/deals/#{deal.id}/emails",
          params: { email: { to_address: "bad", subject: "Hi", body: "Hello" } },
          headers: headers
      }.not_to change(EmailMessage, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "does not allow emailing a deal from another workspace" do
      foreign_deal = create_deal!(workspaces(:two))

      expect {
        post "/api/v1/deals/#{foreign_deal.id}/emails", params: valid_params, headers: headers
      }.not_to change(EmailMessage, :count)

      expect(response).to have_http_status(:not_found)
    end

    context "with Base64 attachments" do
      let(:pdf_content) { Base64.strict_encode64("%PDF-1.4 fake report") }

      before do
        allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)
      end

      it "attaches the decoded file to the message and lists it in the response" do
        params = {
          email: {
            to_address: "lead@example.com",
            subject: "Tu informe",
            body: "Adjuntamos tu informe.",
            attachments: [
              { filename: "informe.pdf", content_type: "application/pdf", content: pdf_content }
            ]
          }
        }

        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: params, headers: headers, as: :json
        }.to change(EmailMessage, :count).by(1)
          .and have_enqueued_mail(RecordMailer, :tracked_email)

        message = EmailMessage.order(:id).last
        expect(response).to have_http_status(:created)
        expect(message.attachments.count).to eq(1)
        expect(message.attachments.first.filename.to_s).to eq("informe.pdf")
        expect(message.attachments.first.download).to eq("%PDF-1.4 fake report")
        expect(response.parsed_body["attachments"]).to eq([ "informe.pdf" ])
      end

      it "rejects invalid Base64 content with 422" do
        params = {
          email: {
            to_address: "lead@example.com",
            subject: "Hi",
            body: "Hello",
            attachments: [ { filename: "informe.pdf", content: "not-base64!!!" } ]
          }
        }

        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: params, headers: headers, as: :json
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "rejects more attachments than the allowed maximum with 422" do
        too_many = Array.new(EmailMessage::MAX_ATTACHMENTS + 1) do |i|
          { filename: "f#{i}.txt", content: Base64.strict_encode64("x") }
        end
        params = {
          email: { to_address: "lead@example.com", subject: "Hi", body: "Hello", attachments: too_many }
        }

        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: params, headers: headers, as: :json
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects a non-object attachment entry with 422" do
        params = {
          email: {
            to_address: "lead@example.com",
            subject: "Hi",
            body: "Hello",
            attachments: [ "just-a-string" ]
          }
        }

        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: params, headers: headers, as: :json
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects an attachment without content with 422" do
        params = {
          email: {
            to_address: "lead@example.com",
            subject: "Hi",
            body: "Hello",
            attachments: [ { filename: "informe.pdf" } ]
          }
        }

        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: params, headers: headers, as: :json
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with multipart attachments" do
      let(:uploaded_file) do
        Rack::Test::UploadedFile.new(
          StringIO.new("%PDF-1.4 fake report"),
          "application/pdf",
          original_filename: "informe.pdf"
        )
      end

      before do
        allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)
      end

      it "attaches uploaded files to the message" do
        params = {
          email: {
            to_address: "lead@example.com",
            subject: "Tu informe",
            body: "Adjuntamos tu informe.",
            attachments: [ uploaded_file ]
          }
        }

        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: params, headers: headers
        }.to change(EmailMessage, :count).by(1)
          .and have_enqueued_mail(RecordMailer, :tracked_email)

        message = EmailMessage.order(:id).last
        expect(response).to have_http_status(:created)
        expect(message.attachments.count).to eq(1)
        expect(message.attachments.first.filename.to_s).to eq("informe.pdf")
        expect(message.attachments.first.download).to eq("%PDF-1.4 fake report")
        expect(response.parsed_body["attachments"]).to eq([ "informe.pdf" ])
      end
    end

    context "when record_email is disabled" do
      before do
        allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(false)
      end

      it "returns not found" do
        expect {
          post "/api/v1/deals/#{deal.id}/emails", params: valid_params, headers: headers
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
