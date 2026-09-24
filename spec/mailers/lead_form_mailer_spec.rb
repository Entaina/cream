require "rails_helper"

RSpec.describe LeadFormMailer, type: :mailer do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:responsible) { users(:one) }
  let(:lead_form) { create_lead_form!(workspace, user: responsible) }
  let(:person) { create_person!(workspace, company: companies(:acme), email: "lead@example.com") }
  let(:submission) do
    workspace.lead_submissions.create!(
      lead_form: lead_form,
      person: person,
      capture_destination: "mql",
      data: {"email" => "lead@example.com"},
      metadata: {"gdpr_consent_at" => Time.current.iso8601}
    )
  end
  let(:deal) { create_deal!(workspace, company: person.company, contacts: [person]) }

  it "notifies the responsible user" do
    mail = described_class.responsible_notification(
      responsible: responsible,
      lead_form: lead_form,
      submission: submission,
      deal: deal
    )

    expect(mail.to).to eq([responsible.email_address])
    expect(mail.subject).to include(lead_form.name)
  end
end
