require "rails_helper"

RSpec.describe StripeSyncService do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:connection) do
    workspace.stripe_connections.create!(user: user, api_key: "rk_test_123", sync_enabled: true)
  end

  # Fake client honouring the created_after cursor like the real one.
  def client_with(charges)
    client = instance_double(StripeClient)
    allow(client).to receive(:list_charges) do |created_after: nil, &block|
      charges.each do |charge|
        next if created_after.present? && charge["created"] <= created_after.to_i

        block.call(charge)
      end
    end
    client
  end

  def charge(id:, created:, amount: 50_000, email: "pat@example.com", **attrs)
    {
      "id" => id, "status" => "succeeded", "paid" => true,
      "amount" => amount, "currency" => "eur", "created" => created,
      "billing_details" => {"email" => email, "name" => "Pat Doe"},
      "customer" => "cus_1", "description" => "Course", "metadata" => {},
      "refunded" => false, "livemode" => false
    }.merge(attrs)
  end

  it "imports succeeded charges and advances the cursor" do
    client = client_with([charge(id: "ch_1", created: 100), charge(id: "ch_2", created: 200)])

    expect(described_class.new(connection: connection, client: client).sync!).to be(true)

    expect(workspace.stripe_payments.pluck(:stripe_charge_id)).to contain_exactly("ch_1", "ch_2")
    payment = workspace.stripe_payments.find_by(stripe_charge_id: "ch_1")
    expect(payment.amount_cents).to eq(50_000)
    expect(payment.customer_email).to eq("pat@example.com")
    expect(payment.paid_at).to eq(Time.zone.at(100))
    expect(payment.payload["id"]).to eq("ch_1")
    expect(connection.reload.sync_cursor).to eq(200)
    expect(connection.last_synced_at).to be_present
    expect(connection.last_error).to be_nil
  end

  it "stores the full charge payload and falls back to the expanded customer email" do
    client = client_with([charge(:id => "ch_1", :created => 100, :email => nil,
      "customer" => {"id" => "cus_9", "email" => "fallback@example.com", "name" => "Cust Name"})])

    described_class.new(connection: connection, client: client).sync!

    payment = workspace.stripe_payments.find_by!(stripe_charge_id: "ch_1")
    expect(payment.customer_email).to eq("fallback@example.com")
    expect(payment.stripe_customer_id).to eq("cus_9")
    expect(payment.payload.dig("customer", "email")).to eq("fallback@example.com")
  end

  it "skips non-succeeded charges" do
    client = client_with([charge(:id => "ch_fail", :created => 100, "status" => "failed", "paid" => false)])

    described_class.new(connection: connection, client: client).sync!

    expect(workspace.stripe_payments.count).to eq(0)
  end

  it "is idempotent and never overwrites user decisions" do
    client = client_with([charge(id: "ch_1", created: 100)])
    service = described_class.new(connection: connection, client: client)
    service.sync!

    payment = workspace.stripe_payments.find_by!(stripe_charge_id: "ch_1")
    payment.ignore!(user: user)
    connection.update!(sync_cursor: nil) # force a full re-read

    described_class.new(connection: connection, client: client).sync!

    expect(workspace.stripe_payments.where(stripe_charge_id: "ch_1").count).to eq(1)
    expect(payment.reload).to be_ignored
  end

  it "persists match suggestions at import time" do
    Pipeline.create_default!(workspace)
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "pat@example.com")
    deal = create_deal!(workspace, company: company, contacts: [person], value: 500)

    client = client_with([charge(id: "ch_1", created: 100)])
    described_class.new(connection: connection, client: client).sync!

    payment = workspace.stripe_payments.find_by!(stripe_charge_id: "ch_1")
    expect(payment.suggested_deal).to eq(deal)
    expect(payment.suggested_person).to eq(person)
    expect(payment.match_confidence).to eq("high")
  end

  it "refreshes stale suggestions of pending payments on later syncs" do
    client = client_with([charge(id: "ch_1", created: 100)])
    described_class.new(connection: connection, client: client).sync!
    payment = workspace.stripe_payments.find_by!(stripe_charge_id: "ch_1")
    expect(payment.match_confidence).to eq("none")

    Pipeline.create_default!(workspace)
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "pat@example.com")
    create_deal!(workspace, company: company, contacts: [person], value: 500)

    described_class.new(connection: connection, client: client).sync!

    expect(payment.reload.match_confidence).to eq("high")
  end

  it "syncs manually even when auto-import is disabled" do
    connection.update!(sync_enabled: false)
    client = client_with([charge(id: "ch_1", created: 100)])

    expect(described_class.new(connection: connection, client: client).sync!).to be(true)
    expect(workspace.stripe_payments.count).to eq(1)
  end

  describe "payload backfill" do
    def legacy_payment!(**attrs)
      workspace.stripe_payments.create!({
        stripe_connection: connection, stripe_charge_id: "ch_old",
        amount_cents: 50_000, currency: "eur", paid_at: Time.current, payload: {}
      }.merge(attrs))
    end

    it "re-fetches charges imported without payload and fills the missing fields" do
      payment = legacy_payment!
      client = client_with([])
      allow(client).to receive(:get_charge).with("ch_old").and_return(
        "id" => "ch_old", "receipt_url" => "https://stripe/r/1", "refunded" => true,
        "billing_details" => {"email" => "pat@example.com", "name" => "Pat Doe"},
        "customer" => {"id" => "cus_1"}
      )

      described_class.new(connection: connection, client: client).sync!

      payment.reload
      expect(payment.payload["receipt_url"]).to eq("https://stripe/r/1")
      expect(payment.customer_email).to eq("pat@example.com")
      expect(payment.stripe_customer_id).to eq("cus_1")
      expect(payment.refunded).to be(true)
    end

    it "recomputes suggestions with the backfilled email in the same run" do
      Pipeline.create_default!(workspace)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "pat@example.com")
      deal = create_deal!(workspace, company: company, contacts: [person], value: 500)
      payment = legacy_payment!
      client = client_with([])
      allow(client).to receive(:get_charge).and_return(
        "id" => "ch_old", "billing_details" => {"email" => "pat@example.com"}
      )

      described_class.new(connection: connection, client: client).sync!

      expect(payment.reload.suggested_deal).to eq(deal)
      expect(payment.match_confidence).to eq("high")
    end

    it "keeps going when one charge fails to fetch" do
      failing = legacy_payment!(stripe_charge_id: "ch_gone")
      ok = legacy_payment!(stripe_charge_id: "ch_ok")
      client = client_with([])
      allow(client).to receive(:get_charge).with("ch_gone").and_raise(StripeClient::Error, "nope")
      allow(client).to receive(:get_charge).with("ch_ok").and_return("id" => "ch_ok")

      expect(described_class.new(connection: connection, client: client).sync!).to be(true)

      expect(failing.reload.payload).to eq({})
      expect(ok.reload.payload["id"]).to eq("ch_ok")
    end

    it "does not touch matched payments' decisions" do
      Pipeline.create_default!(workspace)
      deal = create_deal!(workspace)
      payment = legacy_payment!
      payment.match!(deal, user: user)
      client = client_with([])
      allow(client).to receive(:get_charge).and_return("id" => "ch_old", "receipt_url" => "https://stripe/r/2")

      described_class.new(connection: connection, client: client).sync!

      payment.reload
      expect(payment).to be_matched
      expect(payment.deal).to eq(deal)
      expect(payment.payload["receipt_url"]).to eq("https://stripe/r/2")
    end
  end

  it "does nothing without an API key" do
    connection.update!(api_key: nil)
    client = instance_double(StripeClient)

    expect(described_class.new(connection: connection, client: client).sync!).to be(false)
  end

  it "records the error and returns false on API failure" do
    client = instance_double(StripeClient)
    allow(client).to receive(:list_charges).and_raise(StripeClient::AuthenticationError, "bad key")

    expect(described_class.new(connection: connection, client: client).sync!).to be(false)
    expect(connection.reload.last_error).to eq("bad key")
  end
end
