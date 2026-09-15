require "rails_helper"

RSpec.describe MailMergeJob, type: :job do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme), email: "lead@example.com") }

  it "attaches template files to each sent message" do
    template = workspace.email_templates.create!(user: user, name: "Intro", subject: "Hi", body: "Hello {name}")
    template.attachments.attach(
      io: StringIO.new("template file"),
      filename: "template.txt",
      content_type: "text/plain"
    )

    mail = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    allow(RecordMailer).to receive(:tracked_email).and_return(mail)

    described_class.perform_now(workspace.id, user.id, "Person", [person.id], "Hi", "Body", template.id)

    message = workspace.email_messages.order(:id).last
    expect(message.attachments.count).to eq(1)
    expect(message.attachments.first.filename.to_s).to eq("template.txt")
    expect(RecordMailer).to have_received(:tracked_email).with(message: message)
  end
end
