require "rails_helper"

RSpec.describe Journey, type: :model do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "requires a product when stop_on_open_deal is enabled" do
    journey = workspace.journeys.new(name: "Nurture", entry_trigger: "manual", stop_on_open_deal: true)

    expect(journey).not_to be_valid
    expect(journey.errors[:product]).to be_present
  end

  it "normalizes blank entry config values" do
    journey = workspace.journeys.create!(
      name: "Welcome",
      entry_trigger: "manual",
      entry_config: {"segment_id" => "", "lifecycle_stage" => "lead"}
    )

    expect(journey.entry_config).to eq("lifecycle_stage" => "lead")
  end
end
