require "rails_helper"

RSpec.describe Marketing::EmailContent do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, first_name: "Ana", email: "ana@example.com") }
  let(:layout) do
    workspace.email_layouts.create!(
      name: "Shell",
      body: "<html><body>{{ content }}</body></html>"
    )
  end

  describe ".from_campaign" do
    it "renders inline body with layout" do
      campaign = workspace.campaigns.create!(
        name: "News",
        status: "draft",
        email_subject: "Hola {first_name}",
        email_body: "<p>Hola {first_name}</p>",
        email_layout: layout
      )

      content = described_class.from_campaign(campaign)
      expect(content).to be_present
      expect(content.render_subject_for(person)).to eq("Hola Ana")
      expect(content.render_for(person)).to include("<p>Hola Ana</p>")
      expect(content.render_for(person)).to include("<html>")
    end

    it "falls back to base template when body is blank" do
      template = create_email_template!(workspace, user: user, subject: "Tpl", body: "Desde plantilla {first_name}")
      campaign = workspace.campaigns.create!(
        name: "News",
        status: "draft",
        email_template: template
      )

      content = described_class.from_campaign(campaign)
      expect(content.render_for(person)).to include("Desde plantilla Ana")
    end
  end

  describe ".from_journey_step" do
    it "renders inline config body" do
      journey = workspace.journeys.create!(name: "J", entry_trigger: "manual", active: true)
      step = journey.steps.create!(
        position: 0,
        step_type: "send_email",
        active: true,
        config: {
          "subject" => "Paso {first_name}",
          "body" => "<p>Recorrido {first_name}</p>",
          "body_editor" => "html",
          "email_layout_id" => layout.id
        }
      )

      content = described_class.from_journey_step(step, workspace: workspace)
      expect(content.render_subject_for(person)).to eq("Paso Ana")
      expect(content.render_for(person)).to include("Recorrido Ana")
    end
  end
end
