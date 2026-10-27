require "rails_helper"

RSpec.describe EmailVerificationsMailer, type: :mailer do
  it "sends a confirmation link" do
    user = User.create!(name: "Pending", email_address: "pending@example.com", password: "password")
    mail = described_class.verify(user)

    expect(mail.to).to eq([ user.email_address ])
    expect(mail.subject).to eq(I18n.t("email_verifications_mailer.verify.subject"))
    expect(mail.text_part.body.decoded).to include("/email_verifications/")
  end
end
