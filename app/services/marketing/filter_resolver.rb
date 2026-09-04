module Marketing
  class FilterResolver
    def initialize(workspace:, record_type:, filters:)
      @workspace = workspace
      @record_type = record_type
      @filters = filters.to_h.stringify_keys
    end

    def resolve(scope)
      scope = apply_search(scope)
      scope = apply_native_filters(scope)
      scope = apply_custom_fields(scope)
      scope = apply_extra_filters(scope)
      scope = apply_behavior_filters(scope)
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
        scope = apply_contains(scope, "people.email", @filters["email_contains"]) if @filters["email_contains"].present?
        scope = apply_contains(scope, "people.job_title", @filters["job_title_contains"]) if @filters["job_title_contains"].present?
        scope = apply_numeric_range(scope, "people.lead_score", @filters["lead_score_min"], @filters["lead_score_max"])
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
      scope.where("#{column} ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(value)}%")
    end

    def apply_numeric_range(scope, column, min, max)
      scope = scope.where("#{column} >= ?", min.to_i) if min.present?
      scope = scope.where("#{column} <= ?", max.to_i) if max.present?
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
        scope = scope.joins(:email_messages).where(email_messages: { opened_at: days.days.ago.. })
      end
      if @filters["submitted_form_slug"].present?
        scope = scope.joins(lead_submissions: :lead_form)
          .where(lead_forms: { slug: @filters["submitted_form_slug"] })
      end
      if @filters["visited_url"].present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@filters["visited_url"])}%"
        scope = scope.joins(:page_views).where("page_views.url ILIKE ?", pattern)
      end
      scope
    end

    def apply_behavior_filters(scope)
      return scope unless @record_type == "Person"
      return scope unless @filters["exclude_suppressed"].in?([ true, "true", "1", 1 ])

      suppressed = @workspace.email_suppressions.pluck(:address)
      return scope if suppressed.empty?

      scope.where.not(email: suppressed).where.not(id: PersonEmail.where(address: suppressed).select(:person_id))
    end
  end
end
