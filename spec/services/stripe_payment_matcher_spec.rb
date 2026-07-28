require "rails_helper"

RSpec.describe StripePaymentMatcher do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:connection) do
    workspace.stripe_connections.create!(user: user, api_key: "rk_test_123")
  end

  def build_payment(**attrs)
    workspace.stripe_payments.new({
      stripe_connection: connection,
      stripe_charge_id: "ch_#{SecureRandom.hex(4)}",
      amount_cents: 50_000,
      currency: "eur",
      customer_email: "pat@example.com",
      metadata: {},
      paid_at: Time.current
    }.merge(attrs))
  end

  def person_with_deal(email: "pat@example.com", value: 500, currency: "EUR", stage: nil)
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: email)
    deal = create_deal!(workspace, company: company, contacts: [ person ],
      value: value, currency: currency, stage: stage)
    [ person, deal ]
  end

  it "matches high via cream_deal_id metadata" do
    _person, deal = person_with_deal
    result = described_class.new(build_payment(metadata: { "cream_deal_id" => deal.id.to_s },
      customer_email: nil)).call

    expect(result.deal).to eq(deal)
    expect(result.confidence).to eq("high")
  end

  it "ignores metadata deal ids from another workspace" do
    other_pipeline = Pipeline.create_default!(workspaces(:two))
    foreign = create_deal!(workspaces(:two), pipeline: other_pipeline)

    result = described_class.new(build_payment(metadata: { "cream_deal_id" => foreign.id.to_s },
      customer_email: nil)).call

    expect(result.deal).to be_nil
    expect(result.confidence).to eq("none")
  end

  it "matches high on email + single open deal with agreeing amount and currency" do
    person, deal = person_with_deal(value: 500)

    result = described_class.new(build_payment).call

    expect(result.deal).to eq(deal)
    expect(result.person).to eq(person)
    expect(result.confidence).to eq("high")
  end

  it "degrades to medium when the currency differs" do
    _person, deal = person_with_deal(value: 500, currency: "USD")

    result = described_class.new(build_payment).call

    expect(result.deal).to eq(deal)
    expect(result.confidence).to eq("medium")
  end

  it "matches medium on email + single open deal with a different amount" do
    _person, deal = person_with_deal(value: 999)

    result = described_class.new(build_payment).call

    expect(result.deal).to eq(deal)
    expect(result.confidence).to eq("medium")
  end

  it "returns low with several candidate deals" do
    person, _deal = person_with_deal(value: 100)
    create_deal!(workspace, company: person.company, contacts: [ person ], value: 200)

    result = described_class.new(build_payment).call

    expect(result.confidence).to eq("low")
    expect(result.person).to eq(person)
  end

  it "matches high on a won deal with agreeing amount (payments often arrive after winning)" do
    won = pipeline.pipeline_stages.find_by!(name: "Won")
    person, deal = person_with_deal(stage: won, value: 500)

    result = described_class.new(build_payment).call

    expect(result.deal).to eq(deal)
    expect(result.person).to eq(person)
    expect(result.confidence).to eq("high")
  end

  it "prefers the open deal when open and won both match the amount" do
    won = pipeline.pipeline_stages.find_by!(name: "Won")
    person, open_deal = person_with_deal(value: 500)
    create_deal!(workspace, company: person.company, contacts: [ person ], value: 500, stage: won)

    result = described_class.new(build_payment).call

    expect(result.deal).to eq(open_deal)
    expect(result.confidence).to eq("high")
  end

  it "matches medium on a single won deal without amount agreement" do
    won = pipeline.pipeline_stages.find_by!(name: "Won")
    _person, deal = person_with_deal(stage: won, value: 999)

    result = described_class.new(build_payment).call

    expect(result.deal).to eq(deal)
    expect(result.confidence).to eq("medium")
  end

  it "ignores lost deals entirely" do
    lost = pipeline.pipeline_stages.find_by!(name: "Lost")
    person, _deal = person_with_deal(stage: lost, value: 500)

    result = described_class.new(build_payment).call

    expect(result.deal).to be_nil
    expect(result.person).to eq(person)
    expect(result.confidence).to eq("low")
  end

  it "collects deals across people sharing the email" do
    person_with_deal(value: 100)
    person_with_deal(value: 200)

    result = described_class.new(build_payment).call

    expect(result.confidence).to eq("low")
  end

  it "returns none for an unknown email" do
    result = described_class.new(build_payment(customer_email: "stranger@example.com")).call

    expect(result.deal).to be_nil
    expect(result.person).to be_nil
    expect(result.confidence).to eq("none")
  end

  it "matches emails case-insensitively" do
    person, _deal = person_with_deal(email: "Pat@Example.com")

    result = described_class.new(build_payment(customer_email: "pat@example.COM")).call

    expect(result.person).to eq(person)
  end
end
