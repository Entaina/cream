class StripePayment < ApplicationRecord
  STATUSES = %w[pending_review matched ignored].freeze
  CONFIDENCES = %w[high medium low none].freeze

  belongs_to :workspace
  belongs_to :stripe_connection
  belongs_to :deal, optional: true
  belongs_to :suggested_deal, class_name: "Deal", optional: true
  belongs_to :suggested_person, class_name: "Person", optional: true
  belongs_to :matched_by, class_name: "User", optional: true

  validates :stripe_charge_id, presence: true, uniqueness: {scope: :workspace_id}
  validates :status, inclusion: {in: STATUSES}
  validates :match_confidence, inclusion: {in: CONFIDENCES}, allow_nil: true

  scope :pending_review, -> { where(status: "pending_review") }
  scope :matched, -> { where(status: "matched") }
  scope :ignored, -> { where(status: "ignored") }
  scope :recent_first, -> { order(paid_at: :desc, id: :desc) }
  scope :search, ->(q) {
    next if q.blank?
    where("customer_email ILIKE :q OR customer_name ILIKE :q OR description ILIKE :q",
      q: "%#{sanitize_sql_like(q)}%")
  }

  def pending_review? = status == "pending_review"
  def matched? = status == "matched"
  def ignored? = status == "ignored"

  # Stripe amounts come in minor units. Dividing by 100 is wrong for
  # zero-decimal currencies (JPY…) — acceptable here, workspaces bill in EUR.
  def amount_decimal
    amount_cents / 100.0
  end

  # --- Read-through helpers over the raw Stripe charge stored in `payload`.

  def receipt_url = payload["receipt_url"]

  def amount_refunded_decimal
    payload["amount_refunded"].to_i / 100.0
  end

  def partially_refunded?
    payload["amount_refunded"].to_i.positive? && !refunded?
  end

  # "Visa ···4242", "Bizum", "SEPA Direct Debit"…
  def payment_method_summary
    details = payload["payment_method_details"] || {}
    type = details["type"]
    return nil if type.blank?

    card = details[type].is_a?(Hash) ? details[type] : {}
    if card["brand"].present? && card["last4"].present?
      "#{card["brand"].capitalize} ···#{card["last4"]}"
    else
      type.humanize
    end
  end

  def customer_phone
    payload.dig("billing_details", "phone").presence || expanded_customer["phone"]
  end

  def billing_address
    address = payload.dig("billing_details", "address").presence&.compact_blank.presence ||
      expanded_customer["address"] || {}
    [address["line1"], address["line2"], address["postal_code"], address["city"],
      address["state"], address["country"]].compact_blank.join(", ").presence
  end

  def risk_outcome
    payload.dig("outcome", "seller_message")
  end

  def stripe_payment_intent_id
    intent = payload["payment_intent"]
    intent.is_a?(Hash) ? intent["id"] : intent
  end

  def expanded_customer
    payload["customer"].is_a?(Hash) ? payload["customer"] : {}
  end

  def match!(deal, user:)
    update!(status: "matched", deal: deal, matched_by: user, matched_at: Time.current)
    deal.track_activity(
      "payment_received",
      user: user,
      metadata: {
        amount: amount_decimal,
        currency: currency.upcase,
        stripe_charge_id: stripe_charge_id,
        customer_email: customer_email,
        stripe_payment_id: id
      }.compact
    )
  end

  # Keeps suggestions so unignore! restores the row as it was.
  def ignore!(user:)
    update!(status: "ignored", matched_by: user)
  end

  def unignore!
    update!(status: "pending_review", matched_by: nil)
  end
end
