class AlertRuleEngine
  def self.run!(workspace)
    workspace.alert_rules.active.find_each do |rule|
      new(rule).run!
    end
  end

  def initialize(rule)
    @rule = rule
    @workspace = rule.workspace
  end

  def run!
    matching_deals.find_each do |deal|
      recipients_for(deal).each do |user, membership|
        next if already_delivered?(deal, user)

        delivered = deliver(deal, user, membership)
        record_delivery(deal, user) if delivered
      end
    end
  end

  private

  attr_reader :rule, :workspace

  def matching_deals
    scope = workspace.deals
    scope = apply_trigger(scope)
    scope = apply_conditions(scope)
    scope = scope.where.not(owner_id: nil) if rule.recipient == "deal_owner"
    scope.distinct
  end

  def apply_trigger(scope)
    offset = rule.offset_days.to_i
    case rule.trigger_field
    when "edition_ends_on"
      scope.joins(deal_products: :edition)
        .where.not(editions: { ends_on: nil })
        .where("editions.ends_on + ?::integer <= ?", offset, Date.current)
    when "edition_starts_on"
      scope.joins(deal_products: :edition)
        .where.not(editions: { starts_on: nil })
        .where("editions.starts_on + ?::integer <= ?", offset, Date.current)
    when "deal_expected_close_date"
      scope.where.not(expected_close_date: nil)
        .where("deals.expected_close_date + ?::integer <= ?", offset, Date.current)
    else
      scope.none
    end
  end

  def apply_conditions(scope)
    Array(rule.conditions).each do |condition|
      case condition
      when "company_without_fiscal_info"
        scope = scope.joins(:company)
          .where("companies.fiscal_information IS NULL OR companies.fiscal_information = ''")
      when "deal_open"
        scope = scope.joins(:pipeline_stage).where(pipeline_stages: { closed: false })
      end
    end
    scope
  end

  def recipients_for(deal)
    case rule.recipient
    when "deal_owner"
      membership = workspace.memberships.find_by(user_id: deal.owner_id)
      return [] unless deal.owner && membership

      [ [ deal.owner, membership ] ]
    when "admins"
      workspace.memberships.admins.includes(:user).map { |membership| [ membership.user, membership ] }
    else
      []
    end
  end

  def deliver(deal, user, membership)
    return false unless membership.alert_in_app? || membership.alert_email?

    NotificationService.notify_alert(recipient: user, rule: rule, deal: deal) if membership.alert_in_app?
    AlertMailer.alert_email(user: user, rule: rule, deal: deal).deliver_later if membership.alert_email?
    true
  end

  def already_delivered?(deal, user)
    rule.alert_deliveries.exists?(deal: deal, user: user)
  end

  def record_delivery(deal, user)
    rule.alert_deliveries.create!(deal: deal, user: user)
  end
end
