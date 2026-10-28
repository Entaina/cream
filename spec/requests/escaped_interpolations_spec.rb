require "rails_helper"

RSpec.describe "Escaping user values inside translated HTML", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:evil) { "<img src=x onerror=alert(1)>" }
  let(:escaped) { "&lt;img src=x onerror=alert(1)&gt;" }

  before { workspace.update!(name: evil, custom_fields_enabled: true) }

  describe "settings pages" do
    before { sign_in_as(admin) }

    [:settings_team_path, :settings_workspace_path, :settings_custom_fields_path].each do |path|
      it "escapes the workspace name on #{path}" do
        get public_send(path)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(escaped)
        expect(response.body).not_to include(evil)
      end
    end

    it "keeps the formatting of the translated text" do
      get settings_team_path

      expect(response.body).to include("<strong>#{escaped}</strong>")
    end
  end

  describe "emails" do
    it "escapes the workspace name in invitations" do
      invitation = workspace.invitations.create!(email_address: "new@example.com", role: "salesperson", invited_by: admin)

      html = InvitationMailer.invite(invitation, "token").html_part.body.decoded

      expect(html).to include(escaped)
      expect(html).not_to include(evil)
    end

    it "escapes the form name in lead form notifications" do
      lead_form = create_lead_form!(workspace, user: admin)
      lead_form.update_columns(name: evil)
      person = create_person!(workspace, company: companies(:acme), email: "lead@example.com")
      submission = workspace.lead_submissions.create!(lead_form: lead_form, person: person, capture_destination: "mql",
        data: {"email" => "lead@example.com"}, metadata: {"gdpr_consent_at" => Time.current.iso8601})

      html = LeadFormMailer.responsible_notification(responsible: admin, lead_form: lead_form,
        submission: submission, deal: create_deal!(workspace, company: person.company, contacts: [person])).html_part.body.decoded

      expect(html).to include(escaped)
      expect(html).not_to include(evil)
    end
  end
end
