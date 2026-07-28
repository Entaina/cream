# Finds groups of Company records that likely represent the same organization.
class CompanyDuplicateGroups
  Group = Data.define(:reason, :companies)

  def self.call(workspace)
    new(workspace).call
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def call
    companies = workspace.companies.order(:created_at, :id).to_a
    return [] if companies.size < 2

    union_find = UnionFind.new(companies.map(&:id))
    reasons_by_pair = {}

    companies.combination(2).each do |first, second|
      reason = match_reason(first, second)
      next unless reason

      union_find.union(first.id, second.id)
      pair_key = [ first.id, second.id ].sort
      reasons_by_pair[pair_key] ||= reason
    end

    companies_by_id = companies.index_by(&:id)
    grouped_ids = union_find.groups.values.select { |ids| ids.size > 1 }

    grouped_ids.map do |ids|
      group_companies = ids.map { |id| companies_by_id[id] }.sort_by { |company| [ company.created_at, company.id ] }
      reason = group_reason(ids, reasons_by_pair)
      Group.new(reason: reason, companies: group_companies)
    end.sort_by { |group| group.companies.first.name }
  end

  private

  attr_reader :workspace

  def match_reason(first, second)
    first_domain = CompanyNameNormalizer.normalize_domain(first.domain)
    second_domain = CompanyNameNormalizer.normalize_domain(second.domain)
    if first_domain.present? && first_domain == second_domain
      return "Same domain"
    end

    first_name = CompanyNameNormalizer.normalize(first.name)
    second_name = CompanyNameNormalizer.normalize(second.name)
    if first_name.length >= 3 && first_name == second_name
      return "Similar name"
    end

    nil
  end

  def group_reason(ids, reasons_by_pair)
    matching_reasons = ids.combination(2).filter_map do |left_id, right_id|
      reasons_by_pair[[ left_id, right_id ].sort]
    end.uniq

    matching_reasons.sort.join(" · ").presence || "Possible duplicate"
  end

  class UnionFind
    def initialize(ids)
      @parent = ids.index_with { |id| id }
    end

    def find(id)
      @parent[id] = find(@parent[id]) if @parent[id] != id
      @parent[id]
    end

    def union(left_id, right_id)
      left_root = find(left_id)
      right_root = find(right_id)
      @parent[right_root] = left_root if left_root != right_root
    end

    def groups
      @parent.keys.group_by { |id| find(id) }
    end
  end
end
