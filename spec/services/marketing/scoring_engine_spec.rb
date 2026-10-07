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

  describe ".apply_event!" do
    it "labels the activities it records without a user as scoring automation" do
      workspace.scoring_rules.create!(name: "Opened email", event_type: "email_opened", points: 20, active: true)
      person.activities.delete_all

      described_class.apply_event!(person: person, event: "email_opened")

      lifecycle = person.activities.where(action: "updated").detect { |a| a.metadata["changes"].key?("lifecycle_stage") }
      expect(lifecycle).to be_present
      expect(lifecycle.user).to be_nil
      expect(person.activities.pluck(:metadata).map { |m| m["automation"] }).to all(eq({"kind" => "scoring"}))
      expect(Current.automation).to be_nil
    end

    it "keeps the signed-in user as the actor" do
      workspace.scoring_rules.create!(name: "Opened email", event_type: "email_opened", points: 20, active: true)
      person.activities.delete_all
      user = workspace.users.first

      Current.set(user: user) { described_class.apply_event!(person: person, event: "email_opened") }

      expect(person.activities.pluck(:user_id).uniq).to eq([user.id])
      expect(person.activities.pluck(:metadata).map { |m| m["automation"] }.compact).to be_empty
    end
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
