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
    expect(mail.from).to eq(["noreply@example.com"])
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

  describe "transactional sender identity" do
    fixtures :companies

    def tracked_mail_for_responsible(responsible:, **connection_attrs)
      attrs = {
        transactional_enabled: true,
        from_email: "noreply@example.com",
        from_name: "Cream",
        sender_domain_validated: false
      }.merge(connection_attrs)
      if workspace.mailjet_connection
        workspace.mailjet_connection.update!(attrs)
      else
        create_connection(**attrs)
      end
      person = create_person!(workspace, company: companies(:acme))
      message = EmailMessage.create!(
        workspace: workspace,
        user: responsible,
        record: person,
        to_address: "recipient@example.com",
        subject: "Subject",
        body: "<p>Hi</p>",
        status: "pending",
        direction: "outbound"
      )
      RecordMailer.tracked_email(message: message).message
    end

    it "keeps the responsible From when the domain is validated and matches Mailjet" do
      responsible = users(:one)
      responsible.update!(name: "Juan Pablo", email_address: "juanpablo@example.com")
      mail = tracked_mail_for_responsible(responsible: responsible, sender_domain_validated: true)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

      described_class.delivering_email(mail)

      expect(mail[:from].to_s).to include("juanpablo@example.com")
      expect(mail[:from].display_names).to eq(["Juan Pablo"])
      expect(mail.reply_to).to eq(["juanpablo@example.com"])
      expect(mail.header[described_class::SENDER_HEADER]).to be_nil
    end

    it "uses workspace From with responsible display name and Reply-To when domain is not validated" do
      responsible = users(:one)
      responsible.update!(name: "Juan Pablo", email_address: "juanpablo@example.com")
      mail = tracked_mail_for_responsible(responsible: responsible, sender_domain_validated: false)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

      described_class.delivering_email(mail)

      expect(mail[:from].to_s).to include("noreply@example.com")
      expect(mail[:from].display_names).to eq(["Juan Pablo"])
      expect(mail.reply_to).to eq(["juanpablo@example.com"])
      expect(mail.header[described_class::SENDER_HEADER]).to be_nil
    end

    it "uses workspace From with Reply-To when the responsible domain differs" do
      responsible = users(:one)
      responsible.update!(name: "Juan Pablo", email_address: "juanpablo@other.com")
      mail = tracked_mail_for_responsible(responsible: responsible, sender_domain_validated: true)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

      described_class.delivering_email(mail)

      expect(mail[:from].to_s).to include("noreply@example.com")
      expect(mail[:from].display_names).to eq(["Juan Pablo"])
      expect(mail.reply_to).to eq(["juanpablo@other.com"])
    end

    it "uses the workspace SMTP connection when Mailjet transactional sending is off" do
      workspace.create_smtp_connection!(
        user: user,
        address: "smtp.workspace.test",
        port: 2525,
        user_name: "smtp-user",
        password: "smtp-secret",
        from_email: "hola@workspace.test",
        from_name: "Workspace"
      )
      mail = mail_for(invitation)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

      described_class.delivering_email(mail)

      expect(mail.delivery_method).to be_a(Mail::SMTP)
      expect(mail.delivery_method.settings[:address]).to eq("smtp.workspace.test")
      expect(mail.delivery_method.settings[:port]).to eq(2525)
      expect(mail.delivery_method.settings[:user_name]).to eq("smtp-user")
      expect(mail.delivery_method.settings[:password]).to eq("smtp-secret")
      expect(mail.from).to eq(["hola@workspace.test"])
    end

    it "keeps Mailjet transactional delivery when a workspace SMTP connection also exists" do
      create_connection(transactional_enabled: true, from_name: "Cream")
      workspace.create_smtp_connection!(
        user: user,
        address: "smtp.workspace.test",
        from_email: "hola@workspace.test",
        user_name: "smtp-user",
        password: "smtp-secret"
      )
      mail = mail_for(invitation)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

      described_class.delivering_email(mail)

      expect(mail.delivery_method.settings[:address]).to eq("in-v3.mailjet.com")
      expect(mail.from).to eq(["noreply@example.com"])
    end

    it "strips the sender header even when Mailjet transactional sending is disabled" do
      responsible = users(:one)
      responsible.update!(email_address: "sales@example.com")
      mail = tracked_mail_for_responsible(responsible: responsible, transactional_enabled: false)
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)

      described_class.delivering_email(mail)

      expect(mail.header[described_class::SENDER_HEADER]).to be_nil
    end
  end
end
