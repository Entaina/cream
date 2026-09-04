require "rails_helper"

RSpec.describe Marketing::ScoringEngine do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "score@example.com", lead_score: 40) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:lead_scoring).and_return(true)
  end

  describe ".apply_decay" do
    it "subtracts half the points of expired rules once, not per rule" do
      workspace.scoring_rules.create!(
        name: "Opened email",
        event_type: "email_opened",
        points: 20,
        decay_days: 30,
        active: true
      )
      workspace.scoring_rules.create!(
        name: "Clicked email",
        event_type: "email_clicked",
        points: 20,
        decay_days: 30,
        active: true
      )
      person.activities.delete_all
      travel_to 45.days.ago do
        person.activities.create!(
          workspace: workspace,
          subject: person,
          action: "email_sent",
          metadata: {}
        )
      end

      decayed = described_class.apply_decay(person)

      expect(decayed).to eq(20)
    end
  end
end
