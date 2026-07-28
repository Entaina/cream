# Deterministic payment → deal matching. Candidates are the payer's linkable
# deals (open or won — payments often arrive after the deal is already won);
# open deals win ties. Confidence tiers:
#   high   — charge metadata carries a deal id, or exactly one candidate with
#            matching currency + amount (±1% tolerance; open breaks ties)
#   medium — exactly one open candidate, or exactly one candidate overall
#   low    — payer identified but the candidates stay ambiguous
#   none   — no person matches the payer email (or no email at all)
class StripePaymentMatcher
  METADATA_KEYS = %w[cream_deal_id deal_id].freeze

  Result = Data.define(:deal, :person, :confidence)

  def initialize(payment)
    @payment = payment
    @workspace = payment.workspace
  end

  def call
    if (deal = deal_from_metadata)
      return Result.new(deal:, person: deal.contacts.first, confidence: "high")
    end

    people = people_by_email
    return Result.new(deal: nil, person: nil, confidence: "none") if people.empty?

    person = people.first
    candidates = linkable_deals_of(people)
    open_candidates = candidates.reject { |deal| deal.pipeline_stage.closed? }
    exact = amount_matches(candidates)
    exact_open = amount_matches(open_candidates)

    if exact.size == 1
      Result.new(deal: exact.first, person:, confidence: "high")
    elsif exact_open.size == 1
      Result.new(deal: exact_open.first, person:, confidence: "high")
    elsif open_candidates.size == 1
      Result.new(deal: open_candidates.first, person:, confidence: "medium")
    elsif candidates.size == 1
      Result.new(deal: candidates.first, person:, confidence: "medium")
    else
      suggestion = open_candidates.max_by(&:created_at) || exact.max_by(&:created_at)
      Result.new(deal: suggestion, person:, confidence: "low")
    end
  end

  def apply!
    result = call
    @payment.assign_attributes(
      suggested_deal: result.deal,
      suggested_person: result.person,
      match_confidence: result.confidence
    )
    result
  end

  private

  def deal_from_metadata
    METADATA_KEYS.each do |key|
      id = @payment.metadata[key]
      next if id.blank?

      deal = @workspace.deals.find_by(id: id)
      return deal if deal
    end
    nil
  end

  def people_by_email
    email = @payment.customer_email.to_s.strip.downcase
    return [] if email.blank?

    @workspace.people.with_email(email).to_a
  end

  def linkable_deals_of(people)
    Deal.linkable
      .includes(:pipeline_stage)
      .joins(:deal_contacts)
      .where(deal_contacts: { person_id: people.map(&:id) })
      .distinct.to_a
  end

  def amount_matches(deals)
    amount = @payment.amount_decimal
    deals.select do |deal|
      deal.currency.to_s.casecmp?(@payment.currency.to_s) &&
        (deal.value.to_f - amount).abs <= [ 0.01, deal.value.to_f * 0.01 ].max
    end
  end
end
