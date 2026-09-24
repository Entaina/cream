require "rails_helper"

RSpec.describe PasswordsMailer, type: :mailer do
  fixtures :users

  let(:user) { users(:one) }

  it "sends reset instructions" do
    mail = described_class.reset(user)

    expect(mail.to).to eq([user.email_address])
    expect(mail.subject).to be_present
  end
end
