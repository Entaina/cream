require "rails_helper"

RSpec.describe Marketing::JourneyExit do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace) }
  let(:product) { workspace.products.create!(name: "Producto A", price: 50) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let!(:journey) do
    workspace.journeys.create!(
      name: "Nurturing A",
      entry_trigger: "manual",
      product: product,
      stop_on_open_deal: true,
      active: true
    )
  end
  let!(:enrollment) do
    step = journey.steps.create!(position: 0, step_type: "wait", config: { "minutes" => 60 })
    JourneyEnrollment.create!(
      workspace: workspace,
      journey: journey,
      person: person,
      current_step: step,
      state: "active",
      enrolled_at: Time.current
    )
  end

  it "blocks enrollment when an open deal exists for the journey product" do
    deal = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [ person ])
    deal.deal_products.create!(product: product, quantity: 1)

    expect(described_class.blocked_by_open_deal?(person: person, journey: journey)).to be(true)
  end

  it "cancels active enrollments when a deal opens" do
    deal = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [ person ])
    deal.deal_products.create!(product: product, quantity: 1)

    described_class.cancel_for_open_deal!(person: person, product: product, deal: deal)

    expect(enrollment.reload.state).to eq("cancelled")
    expect(enrollment.metadata["cancelled_reason"]).to eq("open_deal")
  end
end
