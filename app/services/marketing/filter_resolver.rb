module Marketing
  class FilterResolver
    OPEN_DEAL_VALUES = %w[any yes no].freeze
    CAPTURE_DESTINATIONS = %w[any mql deal].freeze
    SUBSCRIPTION_STATUSES = EmailSubscription::STATUSES + %w[missing].freeze
    INTEREST_STATUSES = Marketing::ProductInterest::STATUSES.freeze

    def initialize(workspace:, record_type:, filters:, deal_scope: nil)
      @workspace = workspace
      @record_type = record_type
      @filters = filters.to_h.stringify_keys
      @deal_scope = deal_scope
    end

    def resolve(scope)
      scope = apply_search(scope)
      scope = apply_native_filters(scope)
      scope = apply_custom_fields(scope)
      scope = apply_extra_filters(scope)
      scope = apply_behavior_filters(scope)
      scope = apply_marketing_filters(scope)
      scope.distinct
    end

    private

    def apply_search(scope)
      return scope unless @filters["q"].present?

      scope.search(@filters["q"])
    end

    def apply_native_filters(scope)
      case @record_type
      when "Person"
        scope = ListFilters.apply_company(scope, @filters["company_id"]) if @filters["company_id"].present?
        scope = ListFilters.apply_owner(scope, @filters["owner_id"]) if @filters["owner_id"].present?
        scope = ListFilters.apply_created_at(scope, @filters.symbolize_keys)
        scope = scope.where(lifecycle_stage: @filters["lifecycle_stage"]) if @filters["lifecycle_stage"].present?
        people = Person.arel_table
        scope = apply_contains(scope, people[:email], @filters["email_contains"]) if @filters["email_contains"].present?
        scope = apply_contains(scope, people[:job_title], @filters["job_title_contains"]) if @filters["job_title_contains"].present?
        scope = apply_numeric_range(scope, people[:lead_score], @filters["lead_score_min"], @filters["lead_score_max"])
        scope = scope.where(source: @filters["source"]) if @filters["source"].present?
      when "Company"
        scope = ListFilters.apply_industry(scope, @filters["industry"]) if @filters["industry"].present?
        scope = ListFilters.apply_owner(scope, @filters["owner_id"]) if @filters["owner_id"].present?
        scope = ListFilters.apply_created_at(scope, @filters.symbolize_keys)
      when "Deal"
        scope = Deal.apply_extra_filters(scope, @filters.symbolize_keys)
      end
      scope
    end

    def apply_contains(scope, column, value)
      scope.where(column.matches("%#{ActiveRecord::Base.sanitize_sql_like(value)}%"))
    end

    def apply_numeric_range(scope, column, min, max)
      scope = scope.where(column.gteq(min.to_i)) if min.present?
      scope = scope.where(column.lteq(max.to_i)) if max.present?
      scope
    end

    def apply_custom_fields(scope)
      return scope unless @filters["cf"].present?

      scope.merge(@record_type.constantize.apply_custom_field_filters(@workspace, @filters["cf"]))
    end

    def apply_extra_filters(scope)
      return scope unless @record_type == "Person"

      if @filters["opened_email_days"].present?
        days = @filters["opened_email_days"].to_i
        scope = scope.joins(:email_messages).where(email_messages: {opened_at: days.days.ago..})
      end
      if @filters["submitted_form_slug"].present?
        scope = scope.joins(lead_submissions: :lead_form)
          .where(lead_forms: {slug: @filters["submitted_form_slug"]})
      end
      if @filters["visited_url"].present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@filters["visited_url"])}%"
        scope = scope.joins(:page_views).where("page_views.url ILIKE ?", pattern)
      end
      scope
    end

    def apply_behavior_filters(scope)
      return scope unless @record_type == "Person"
      return scope unless @filters["exclude_suppressed"].in?([true, "true", "1", 1])

      suppressed = @workspace.email_suppressions.pluck(:address)
      return scope if suppressed.empty?

      scope.where.not(email: suppressed).where.not(id: PersonEmail.where(address: suppressed).select(:person_id))
    end

    def apply_marketing_filters(scope)
      return scope unless @record_type == "Person"

      if truthy?(@filters["marketing_eligible"])
        scope = MqlEligibility.scope(
          workspace: @workspace,
          subscription_type_id: @filters["subscription_type_id"]
        ).where(id: scope.select(:id))
      end

      scope = apply_subscription_filter(scope)
      scope = apply_open_deal_filter(scope)
      scope = apply_interest_filter(scope)
      scope = apply_dealt_product_filter(scope)
      apply_lead_form_capture_filter(scope)
    end

    def apply_subscription_filter(scope)
      type_id = @filters["subscription_type_id"]
      status = @filters["subscription_status"]
      return scope if type_id.blank? && status.blank?
      return scope if type_id.blank? || status.blank?

      type = @workspace.subscription_types.find_by(id: type_id)
      return scope.none unless type

      case status
      when "subscribed", "pending", "unsubscribed"
        scope.joins(:email_subscriptions)
          .where(email_subscriptions: {subscription_type_id: type.id, status: status})
      when "missing"
        subscribed_ids = EmailSubscription.where(subscription_type_id: type.id).select(:person_id)
        scope.where.not(id: subscribed_ids)
      else
        scope
      end
    end

    def apply_open_deal_filter(scope)
      open_deal = @filters["open_deal"].presence || "any"
      return scope unless open_deal.in?(OPEN_DEAL_VALUES - ["any"])

      product_id = @filters["open_deal_product_id"].presence
      open_person_ids = open_deal_person_ids(product_id: product_id)

      if open_deal == "yes"
        scope.where(id: open_person_ids)
      else
        scope.where.not(id: open_person_ids)
      end
    end

    def open_deal_person_ids(product_id: nil)
      deals = (@deal_scope || @workspace.deals).open_deals
      if product_id.present?
        deals = deals.joins(:deal_products).where(deal_products: {product_id: product_id})
      end
      DealContact.where(deal_id: deals.select(:id)).select(:person_id)
    end

    def apply_interest_filter(scope)
      product_id = @filters["interest_product_id"].presence
      return scope if product_id.blank?

      status = @filters["interest_status"].presence || "pending"
      interests = Marketing::ProductInterest.where(workspace: @workspace, product_id: product_id)
      interests = interests.where(status: status) if status.in?(INTEREST_STATUSES)
      scope.where(id: interests.select(:person_id))
    end

    def apply_dealt_product_filter(scope)
      product_id = @filters["dealt_product_id"].presence
      return scope if product_id.blank?

      deal_ids = @workspace.deals.joins(:deal_products).where(deal_products: {product_id: product_id}).select(:id)
      scope.where(id: DealContact.where(deal_id: deal_ids).select(:person_id))
    end

    def apply_lead_form_capture_filter(scope)
      form_id = @filters["lead_form_id"].presence
      destination = @filters["capture_destination"].presence || "any"
      return scope if form_id.blank? && @filters["submitted_from"].blank? && @filters["submitted_to"].blank?

      submissions = LeadSubmission.where(workspace: @workspace)
      submissions = submissions.where(lead_form_id: form_id) if form_id.present?
      if destination.in?(CAPTURE_DESTINATIONS - ["any"])
        submissions = submissions.where(capture_destination: destination)
      end
      if @filters["submitted_from"].present?
        submissions = submissions.where(created_at: parse_date(@filters["submitted_from"]).beginning_of_day..)
      end
      if @filters["submitted_to"].present?
        submissions = submissions.where(created_at: ..parse_date(@filters["submitted_to"]).end_of_day)
      end
      scope.where(id: submissions.select(:person_id))
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError
      Date.current
    end

    def truthy?(value)
      value.in?([true, "true", "1", 1])
    end
  end
end
