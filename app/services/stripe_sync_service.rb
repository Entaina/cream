class StripeSyncService
  # Payments imported before the payload column existed get their full charge
  # re-fetched, this many per sync run (gentle on the Stripe API; the 15-min
  # cadence drains any realistic backlog within a few hours).
  PAYLOAD_BACKFILL_BATCH = 100

  def initialize(connection:, client: nil)
    @connection = connection
    @client = client || StripeClient.new(api_key: connection.api_key)
  end

  # sync_enabled only gates the recurring scheduler (it filters connections);
  # a manual "Sync now" must work regardless of the auto-import toggle.
  def sync!
    return false unless @connection.connected?

    max_created = @connection.sync_cursor.to_i
    @client.list_charges(created_after: @connection.sync_cursor) do |charge|
      next unless charge["status"] == "succeeded" && charge["paid"]

      import_charge!(charge)
      max_created = [max_created, charge["created"].to_i].max
    end

    @connection.update!(
      last_synced_at: Time.current,
      sync_cursor: max_created.positive? ? max_created : nil,
      last_error: nil
    )
    backfill_missing_payloads!
    refresh_pending_suggestions!
    true
  rescue StripeClient::Error => e
    @connection.update!(last_error: e.message.truncate(255))
    Rails.logger.error("Stripe sync failed for StripeConnection##{@connection.id}: #{e.message}")
    false
  end

  private

  def workspace = @connection.workspace

  # Never touch an existing row: matched/ignored are user decisions.
  def import_charge!(charge)
    return if workspace.stripe_payments.exists?(stripe_charge_id: charge["id"])

    billing = charge["billing_details"] || {}
    # With expand[]=data.customer the customer comes as a full object;
    # tolerate the plain id string too (unexpanded payloads, backfills).
    customer = charge["customer"].is_a?(Hash) ? charge["customer"] : {}
    payment = workspace.stripe_payments.new(
      stripe_connection: @connection,
      stripe_charge_id: charge["id"],
      amount_cents: charge["amount"],
      currency: charge["currency"].to_s.presence || "eur",
      customer_email: billing["email"].presence || charge["receipt_email"].presence || customer["email"],
      customer_name: billing["name"].presence || customer["name"],
      stripe_customer_id: customer["id"] || (charge["customer"] if charge["customer"].is_a?(String)),
      description: charge["description"],
      metadata: charge["metadata"] || {},
      payload: charge,
      paid_at: Time.zone.at(charge["created"].to_i),
      refunded: !!charge["refunded"],
      livemode: !!charge["livemode"]
    )
    StripePaymentMatcher.new(payment).apply!
    payment.save!
  end

  # Self-healing for rows imported before `payload` existed: re-fetch the full
  # charge (customer expanded) and fill the fields the old import didn't keep.
  # User decisions (status, deal) are never touched.
  def backfill_missing_payloads!
    @connection.stripe_payments.where(payload: {}).limit(PAYLOAD_BACKFILL_BATCH).each do |payment|
      charge = @client.get_charge(payment.stripe_charge_id)
      customer = charge["customer"].is_a?(Hash) ? charge["customer"] : {}
      payment.payload = charge
      payment.customer_email ||= charge.dig("billing_details", "email").presence ||
        charge["receipt_email"].presence || customer["email"]
      payment.customer_name ||= charge.dig("billing_details", "name").presence || customer["name"]
      payment.stripe_customer_id ||= customer["id"]
      payment.refunded = !!charge["refunded"]
      payment.save!
    rescue StripeClient::Error => e
      Rails.logger.warn("Stripe payload backfill failed for #{payment.stripe_charge_id}: #{e.message}")
    end
  end

  # Deals/people created after an import can make old suggestions stale;
  # pending payments are cheap to re-match on every sync.
  def refresh_pending_suggestions!
    workspace.stripe_payments.pending_review.find_each do |payment|
      StripePaymentMatcher.new(payment).apply!
      payment.save! if payment.changed?
    end
  end
end
