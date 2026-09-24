require "rails_helper"

RSpec.describe MarketingDataRetentionJob, type: :job do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "deletes old page views" do
    person = create_person!(workspace)
    PageView.create!(
      workspace: workspace,
      person: person,
      anonymous_id: "anon-1",
      url: "https://example.com",
      occurred_at: 200.days.ago
    )

    expect {
      described_class.perform_now
    }.to change(PageView, :count).by(-1)
  end
end
