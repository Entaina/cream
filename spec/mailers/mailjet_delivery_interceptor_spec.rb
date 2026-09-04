require "rails_helper"

RSpec.describe MailjetDeliveryInterceptor do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:invitation) do
    workspace.invitations.create!(
      invited_by: user,
      email_address: "join@example.com",
      role: "salesperson"
    )
  end

  def mail_for(invitation)
    InvitationMailer.invite(invitation, invitation.plaintext_token).message
  end

  def create_connection(**attrs)
    workspace.create_mailjet_connection!({
      user: user,
      api_key: "api-key-xxxx",
      secret_key: "secret-yyyy",
      from_email: "noreply@example.com"
    }.merge(attrs))
  end

  it "does not override the test delivery method" do
    create_connection(transactional_enabled: true, from_name: "Cream")
    mail = mail_for(invitation)

    described_class.delivering_email(mail)

    expect(mail.delivery_method).to be_a(Mail::TestMailer)
    expect(mail.header[described_class::HEADER]).to be_nil
  end

  it "switches transactional mail to Mailjet SMTP when enabled" do
    create_connection(transactional_enabled: true, from_name: "Cream")
    mail = mail_for(invitation)
    allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

    described_class.delivering_email(mail)

    expect(mail.delivery_method).to be_a(Mail::SMTP)
    expect(mail.delivery_method.settings[:user_name]).to eq("api-key-xxxx")
    expect(mail.delivery_method.settings[:password]).to eq("secret-yyyy")
    expect(mail.delivery_method.settings[:address]).to eq("in-v3.mailjet.com")
    expect(mail.from).to eq([ "noreply@example.com" ])
    expect(mail.header[described_class::HEADER]).to be_nil
  end

  it "leaves default delivery when transactional sending is disabled" do
    create_connection(transactional_enabled: false)
    mail = mail_for(invitation)
    allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

    described_class.delivering_email(mail)

    expect(mail.delivery_method).to be_a(Mail::TestMailer)
  end

  it "leaves default delivery when the workspace has no Mailjet connection" do
    mail = mail_for(invitation)
    allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

    described_class.delivering_email(mail)

    expect(mail.delivery_method).to be_a(Mail::TestMailer)
    expect(mail.header[described_class::HEADER]).to be_nil
  end

  it "tags password reset with the user's default workspace when possible" do
    create_connection(transactional_enabled: true)
    mail = PasswordsMailer.reset(user).message
    allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

    described_class.delivering_email(mail)

    expect(mail.delivery_method.settings[:user_name]).to eq("api-key-xxxx")
  end
end
