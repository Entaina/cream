require "rails_helper"

RSpec.describe StripePayment, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:connection) do
    workspace.stripe_connections.create!(user: user, api_key: "rk_test_123", sync_enabled: true)
  end

  def create_payment!(**attrs)
    workspace.stripe_payments.create!({
      stripe_connection: connection,
      stripe_charge_id: "ch_#{SecureRandom.hex(4)}",
      amount_cents: 15_000,
      currency: "eur",
      customer_email: "pat@example.com",
      paid_at: Time.current
    }.merge(attrs))
  end

  it "rejects a duplicate charge id within the workspace" do
    create_payment!(stripe_charge_id: "ch_dup")
    dup = workspace.stripe_payments.new(stripe_connection: connection,
      stripe_charge_id: "ch_dup", paid_at: Time.current)

    expect(dup).not_to be_valid
    expect(dup.errors[:stripe_charge_id]).to be_present
  end

  it "converts minor units to a decimal amount" do
    expect(create_payment!(amount_cents: 12_345).amount_decimal).to eq(123.45)
  end

  describe "payload helpers" do
    it "summarizes card payments with brand and last4" do
      payment = create_payment!(payload: {
        "payment_method_details" => { "type" => "card", "card" => { "brand" => "mastercard", "last4" => "4806" } }
      })
      expect(payment.payment_method_summary).to eq("Mastercard ···4806")
    end

    it "humanizes non-card payment methods" do
      payment = create_payment!(payload: { "payment_method_details" => { "type" => "sepa_debit", "sepa_debit" => {} } })
      expect(payment.payment_method_summary).to eq("Sepa debit")
    end

    it "reads phone and address with customer fallback" do
      payment = create_payment!(payload: {
        "billing_details" => { "address" => {}, "phone" => nil },
        "customer" => { "phone" => "+34600111222", "address" => { "city" => "Zaragoza", "country" => "ES" } }
      })
      expect(payment.customer_phone).to eq("+34600111222")
      expect(payment.billing_address).to eq("Zaragoza, ES")
    end

    it "flags partial refunds" do
      payment = create_payment!(payload: { "amount_refunded" => 5000 })
      expect(payment.partially_refunded?).to be(true)
      expect(payment.amount_refunded_decimal).to eq(50.0)
    end
  end

  describe "#match!" do
    it "links the deal and logs a payment_received activity" do
      Pipeline.create_default!(workspace)
      deal = create_deal!(workspace)
      payment = create_payment!

      payment.match!(deal, user: user)

      expect(payment.reload).to be_matched
      expect(payment.deal).to eq(deal)
      expect(payment.matched_by).to eq(user)
      expect(payment.matched_at).to be_present

      activity = deal.activities.find_by(action: "payment_received")
      expect(activity.metadata).to include(
        "amount" => 150.0, "currency" => "EUR", "stripe_charge_id" => payment.stripe_charge_id
      )
    end
  end

  describe "#ignore! / #unignore!" do
    it "flips the status and keeps suggestions" do
      Pipeline.create_default!(workspace)
      deal = create_deal!(workspace)
      payment = create_payment!(suggested_deal: deal, match_confidence: "medium")

      payment.ignore!(user: user)
      expect(payment.reload).to be_ignored
      expect(payment.suggested_deal).to eq(deal)

      payment.unignore!
      expect(payment.reload).to be_pending_review
      expect(payment.match_confidence).to eq("medium")
    end
  end
end
