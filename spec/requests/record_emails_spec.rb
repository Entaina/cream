require "rails_helper"

RSpec.describe "Record emails", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }

  let(:valid_params) do
    {
      record_type: "Company", record_id: company.id,
      email_message: {to_address: "lead@example.com", subject: "Hi", body: "Hello"}
    }
  end

  describe "POST /record_emails" do
    context "when record_email is enabled" do
      before do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      end

      it "creates the message and enqueues the tracked email" do
        sign_in_as(member)

        expect {
          post record_emails_path, params: valid_params
        }.to change(EmailMessage, :count).by(1)
          .and have_enqueued_job(SendViaGmailJob)
          .and change { company.activities.where(action: "email_sent").count }.by(0)

        message = EmailMessage.order(:id).last
        expect(message).to be_queued
        expect(message.record).to eq(company)
        expect(message.user).to eq(member)
        expect(message.workspace).to eq(workspace)
        expect(response).to redirect_to(company_path(company))
      end

      it "stores an HTML body when sending from a deal" do
        sign_in_as(member)
        pipeline = Pipeline.create_default!(workspace)
        deal = create_deal!(workspace, pipeline: pipeline)
        html = "<html><body><table><tr><td>Hola</td></tr></table></body></html>"

        expect {
          post record_emails_path, params: {
            record_type: "Deal", record_id: deal.id,
            email_message: {to_address: "lead@example.com", subject: "Hi", body: html}
          }
        }.to change(EmailMessage, :count).by(1).and have_enqueued_job(SendViaGmailJob)

        expect(EmailMessage.order(:id).last.body).to eq(html)
        expect(response).to redirect_to(deal_path(deal))
      end

      it "rejects an invalid email without sending" do
        sign_in_as(member)

        expect {
          post record_emails_path, params: valid_params.deep_merge(email_message: {to_address: "nope"})
        }.not_to change(EmailMessage, :count)

        expect(response).to redirect_to(company_path(company))
      end

      it "keeps the composer open and shows why a turbo submit was rejected" do
        sign_in_as(member)

        expect {
          post record_emails_path, params: valid_params.deep_merge(email_message: {body: ""}), as: :turbo_stream
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq(Mime[:turbo_stream])
        expect(response.body).to include("toasts")
        expect(response.body).to include(I18n.t("errors.messages.blank"))
      end

      it "does not allow emailing a record from another workspace" do
        sign_in_as(member)
        other = companies(:globex)

        expect {
          post record_emails_path, params: valid_params.merge(record_type: "Company", record_id: other.id)
        }.not_to change(EmailMessage, :count)

        expect(response).to have_http_status(:not_found)
      end

      it "schedules the email when a future send time is given" do
        sign_in_as(member)
        future = nil
        Time.use_zone(member.effective_time_zone(workspace)) do
          future = 1.hour.from_now
          expect {
            post record_emails_path, params: valid_params.merge(scheduled_at: future.strftime("%Y-%m-%dT%H:%M"))
          }.to change(EmailMessage, :count).by(1).and have_enqueued_job(SendScheduledEmailJob)
        end

        message = EmailMessage.order(:id).last
        expect(message).to be_scheduled
        expect(message.scheduled_at).to be_within(1.minute).of(future)
      end

      it "sends immediately when the send time is in the past" do
        sign_in_as(member)

        Time.use_zone(member.effective_time_zone(workspace)) do
          expect {
            post record_emails_path, params: valid_params.merge(scheduled_at: 1.hour.ago.strftime("%Y-%m-%dT%H:%M"))
          }.to have_enqueued_job(SendViaGmailJob)
        end

        expect(EmailMessage.order(:id).last).to be_queued
      end

      it "sets a follow-up reminder and enqueues the follow-up job" do
        sign_in_as(member)

        expect {
          post record_emails_path, params: valid_params.merge(follow_up_days: "7")
        }.to change(EmailMessage, :count).by(1).and have_enqueued_job(EmailFollowUpJob)

        message = EmailMessage.order(:id).last
        expected_follow_up = Time.use_zone(member.effective_time_zone(workspace)) { 7.days.from_now }
        expect(message.follow_up_at).to be_within(1.minute).of(expected_follow_up)
        expect(message).to be_awaiting_follow_up
      end

      it "does not set a follow-up when none is requested" do
        sign_in_as(member)

        post record_emails_path, params: valid_params
        expect(EmailMessage.order(:id).last.follow_up_at).to be_nil
      end

      it "creates the message with an uploaded attachment" do
        sign_in_as(member)
        file = fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")

        expect {
          post record_emails_path, params: valid_params.deep_merge(email_message: {attachments: [file]})
        }.to change(EmailMessage, :count).by(1)

        message = EmailMessage.order(:id).last
        expect(message.attachments).to be_attached
        expect(message.attachments.first.filename.to_s).to eq("sample.txt")
      end

      it "creates the message with a selected record attachment" do
        sign_in_as(member)
        allow(CreamFeatures).to receive(:enabled?).with(:attachments).and_return(true)
        record_attachment = workspace.record_attachments.create!(
          attachable: company, workspace: workspace, user: member,
          file: fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")
        )

        expect {
          post record_emails_path, params: valid_params.merge(record_attachment_ids: [record_attachment.id])
        }.to change(EmailMessage, :count).by(1)

        message = EmailMessage.order(:id).last
        expect(message.attachments.count).to eq(1)
        expect(message.attachments.first.filename.to_s).to eq("sample.txt")
      end

      it "ignores record attachment ids from another record" do
        sign_in_as(member)
        allow(CreamFeatures).to receive(:enabled?).with(:attachments).and_return(true)
        other = companies(:globex)
        other_attachment = workspace.record_attachments.create!(
          attachable: other, workspace: workspace, user: member,
          file: fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")
        )

        post record_emails_path, params: valid_params.merge(record_attachment_ids: [other_attachment.id])

        message = EmailMessage.order(:id).last
        expect(message.attachments).not_to be_attached
      end

      it "copies selected attachments from the email template" do
        sign_in_as(member)
        template = workspace.email_templates.create!(user: member, name: "Intro", subject: "Hi", body: "Hello")
        template.attachments.attach(
          io: StringIO.new("keep"),
          filename: "keep.txt",
          content_type: "text/plain"
        )
        template.attachments.attach(
          io: StringIO.new("skip"),
          filename: "skip.txt",
          content_type: "text/plain"
        )
        keep_id = template.attachments.find { |f| f.filename.to_s == "keep.txt" }.id

        post record_emails_path, params: valid_params.merge(
          email_template_id: template.id,
          email_template_attachment_ids: [keep_id]
        )

        message = EmailMessage.order(:id).last
        expect(message.attachments.count).to eq(1)
        expect(message.attachments.first.filename.to_s).to eq("keep.txt")
      end

      it "does not copy template attachments when none are selected" do
        sign_in_as(member)
        template = workspace.email_templates.create!(user: member, name: "Intro", subject: "Hi", body: "Hello")
        template.attachments.attach(
          io: StringIO.new("template file"),
          filename: "template.txt",
          content_type: "text/plain"
        )

        post record_emails_path, params: valid_params.merge(email_template_id: template.id)

        message = EmailMessage.order(:id).last
        expect(message.attachments).not_to be_attached
      end
    end

    context "when record_email is disabled" do
      before do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(false)
      end

      it "redirects to root with a not-available message" do
        sign_in_as(member)

        expect {
          post record_emails_path, params: valid_params
        }.not_to change(EmailMessage, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /record_emails/:id" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      sign_in_as(member)
    end

    def build_message(status:, scheduled_at: nil)
      workspace.email_messages.create!(user: member, record: company, to_address: "a@b.com",
        subject: "S", body: "B", status: status, scheduled_at: scheduled_at)
    end

    it "cancels a scheduled email" do
      message = build_message(status: "scheduled", scheduled_at: 1.hour.from_now)

      expect { delete record_email_path(message) }.to change(EmailMessage, :count).by(-1)
      expect(response).to redirect_to(company_path(company))
    end

    it "does not delete an already-sent email" do
      message = build_message(status: "sent")

      expect { delete record_email_path(message) }.not_to change(EmailMessage, :count)
    end
  end

  describe "POST /record_emails/:id/retry" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      sign_in_as(member)
    end

    it "queues a failed email again" do
      message = workspace.email_messages.create!(user: member, record: company, to_address: "a@b.com",
        subject: "S", body: "B", status: "failed")

      expect {
        post retry_record_email_path(message)
      }.to have_enqueued_job(SendViaGmailJob).with(message.id)

      expect(message.reload).to be_queued
      expect(response).to redirect_to(company_path(company))
    end

    it "does not resend an email that already went out" do
      message = workspace.email_messages.create!(user: member, record: company, to_address: "a@b.com",
        subject: "S", body: "B", status: "sent")

      expect { post retry_record_email_path(message) }.not_to have_enqueued_job(SendViaGmailJob)
      expect(message.reload.status).to eq("sent")
    end
  end

  describe "PATCH /record_emails/:id/mark_replied" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      sign_in_as(member)
    end

    it "marks the email replied and clears the follow-up state" do
      message = workspace.email_messages.create!(user: member, record: company, to_address: "a@b.com",
        subject: "S", body: "B", status: "sent", follow_up_at: 2.days.from_now)
      expect(message).to be_awaiting_follow_up

      patch mark_replied_record_email_path(message)

      expect(message.reload.replied_at).to be_present
      expect(message).not_to be_awaiting_follow_up
      expect(response).to redirect_to(company_path(company))
    end
  end
end
