require "rails_helper"

RSpec.describe Marketing::MqlToSqlConverter do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:actor) { users(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:product) { workspace.products.create!(name: "Curso IA", price: 100) }
  let(:person) { create_person!(workspace, email: "convert@example.com") }
  let!(:interest) do
    Marketing::ProductInterest.create!(
      workspace: workspace,
      person: person,
      product: product,
      description: "Descargó PDF",
      source_kind: "manual",
      occurred_at: Time.current
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
    type = workspace.subscription_types.find_by!(slug: "general")
    Marketing::ConsentService.subscribe!(person: person, subscription_type: type, source: "spec", legal_basis: "consent")
  end

  it "creates a deal with product line and marks interest converted" do
    result = described_class.call(
      interest: interest,
      actor: actor,
      attributes: {
        "pipeline_id" => pipeline.id,
        "task_title" => "Llamar",
        "task_due_on" => (Date.current + 2.days).to_s
      }
    )

    expect(result.status).to eq("created")
    expect(result.deal).to be_persisted
    expect(result.deal.products).to contain_exactly(product)
    expect(interest.reload).to be_converted
  end

  it "links to an existing open deal for the same product" do
    existing = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person])
    existing.deal_products.create!(product: product, quantity: 1)

    result = described_class.call(
      interest: interest,
      actor: actor,
      attributes: {
        "pipeline_id" => pipeline.id,
        "task_title" => "Llamar",
        "task_due_on" => (Date.current + 2.days).to_s
      }
    )

    expect(result.status).to eq("linked")
    expect(result.deal).to eq(existing)
    expect(Deal.count).to eq(1)
  end

  it "conflicts when multiple visible open deals exist" do
    first = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person], name: "Deal A")
    second = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person], name: "Deal B")
    first.deal_products.create!(product: product, quantity: 1)
    second.deal_products.create!(product: product, quantity: 1)

    result = described_class.call(
      interest: interest,
      actor: actor,
      attributes: {
        "pipeline_id" => pipeline.id,
        "task_title" => "Llamar",
        "task_due_on" => (Date.current + 2.days).to_s
      }
    )

    expect(result.status).to eq("conflict")
    expect(result.message).to include("Multiple open opportunities")
  end

  it "links to a selected open deal when several exist" do
    first = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person], name: "Deal A")
    second = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person], name: "Deal B")
    first.deal_products.create!(product: product, quantity: 1)
    second.deal_products.create!(product: product, quantity: 1)

    result = described_class.call(
      interest: interest,
      actor: actor,
      attributes: {
        "deal_id" => second.id,
        "pipeline_id" => pipeline.id,
        "task_title" => "Llamar",
        "task_due_on" => (Date.current + 2.days).to_s
      }
    )

    expect(result.status).to eq("linked")
    expect(result.deal).to eq(second)
  end

  it "conflicts on retry with incompatible conversion parameters" do
    described_class.call(
      interest: interest,
      actor: actor,
      attributes: {
        "pipeline_id" => pipeline.id,
        "task_title" => "Llamar",
        "task_due_on" => (Date.current + 2.days).to_s
      }
    )

    result = described_class.call(
      interest: interest.reload,
      actor: actor,
      attributes: {
        "pipeline_id" => pipeline.id,
        "task_title" => "Otra tarea",
        "task_due_on" => (Date.current + 5.days).to_s
      }
    )

    expect(result.status).to eq("conflict")
    expect(result.message).to include("different parameters")
  end
end
