# Shared list-index filters used by controllers, SavedView#resolve and report drill-down.
class ListFilters
  NONE = "none"

  def self.apply_owner(scope, owner_id)
    return scope if owner_id.blank?

    if owner_id.to_s == NONE
      scope.where(owner_id: nil)
    else
      scope.where(owner_id: owner_id)
    end
  end

  def self.apply_company(scope, company_id)
    return scope if company_id.blank?

    if company_id.to_s == NONE
      scope.where(company_id: nil)
    else
      scope.where(company_id: company_id)
    end
  end

  def self.apply_industry(scope, industry)
    return scope if industry.blank?

    if industry.to_s == NONE
      scope.where(industry: [nil, ""])
    else
      scope.where(industry: industry)
    end
  end

  def self.apply_created_at(scope, filters)
    filters = filters.symbolize_keys
    scope = scope.where(scope.arel_table[:created_at].gteq(filters[:created_from].to_date.beginning_of_day)) if filters[:created_from].present?
    scope = scope.where(scope.arel_table[:created_at].lteq(filters[:created_to].to_date.end_of_day)) if filters[:created_to].present?
    scope
  end

  def self.apply_pipeline(scope, pipeline_id)
    return scope if pipeline_id.blank? || pipeline_id.to_s == NONE || pipeline_id.to_s == "all"

    scope.where(pipeline_id: pipeline_id)
  end
end
