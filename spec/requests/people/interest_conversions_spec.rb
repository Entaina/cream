require "rails_helper"

RSpec.describe "People::InterestConversions", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:product) { workspace.products.create!(name: "Course", price: 100) }
  let(:person) { create_person!(workspace, email: "convert-ui@example.com") }
  let!(:interest) do
    Marketing::ProductInterest.create!(
      workspace: workspace,
      person: person,
      product: product,
      description: "Requested info",
      source_kind: "manual",
      occurred_at: Time.current
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
    type = workspace.subscription_types.find_by!(slug: "general")
    Marketing::ConsentService.subscribe!(person: person, subscription_type: type, source: "spec", legal_basis: "consent")
    sign_in_as(admin)
  end

  it "converts interest into a deal" do
    expect {
      post "/people/#{person.id}/product_interests/#{interest.id}/conversion", params: {
        conversion: {
          pipeline_id: pipeline.id,
          task_title: "Follow up",
          task_due_on: (Date.current + 2.days).to_s
        }
      }
    }.to change(Deal, :count).by(1)

    expect(response).to redirect_to(Deal.last)
    expect(interest.reload).to be_converted
  end
end
