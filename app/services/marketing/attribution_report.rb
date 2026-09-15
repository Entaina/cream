module Marketing
  class AttributionReport
    Row = Data.define(:key, :label, :visits, :leads, :mqls, :deals, :revenue)

    MQL_STAGES = ScoringEngine::MQL_STAGES

    def initialize(workspace:, utm_source: nil, utm_medium: nil, utm_campaign: nil, date_range: "month")
      @workspace = workspace
      @utm_source = utm_source
      @utm_medium = utm_medium
      @utm_campaign = utm_campaign
      @date_range = date_range
    end

    def rows
      keys = (visit_keys + lead_keys + deal_keys).uniq
      keys.map do |key|
        Row.new(
          key: key,
          label: key,
          visits: visits_for(key),
          leads: leads_for(key),
          mqls: mqls_for(key),
          deals: deals_for(key),
          revenue: revenue_for(key)
        )
      end.sort_by { |row| -row.leads }
    end

    def totals
      rows = self.rows
      Row.new(
        key: "total",
        label: "Total",
        visits: rows.sum(&:visits),
        leads: rows.sum(&:leads),
        mqls: rows.sum(&:mqls),
        deals: rows.sum(&:deals),
        revenue: rows.sum(&:revenue)
      )
    end

    private

    def since
      case @date_range
      when "month" then Time.current.beginning_of_month
      when "quarter" then Time.current.beginning_of_quarter
      when "year" then Time.current.beginning_of_year
      end
    end

    def scoped_page_views
      scope = @workspace.page_views
      scope = scope.where("occurred_at >= ?", since) if since
      scope = scope.where(utm_source: @utm_source) if @utm_source.present?
      scope = scope.where(utm_medium: @utm_medium) if @utm_medium.present?
      scope = scope.where(utm_campaign: @utm_campaign) if @utm_campaign.present?
      scope
    end

    def scoped_leads
      scope = @workspace.lead_submissions
      scope = scope.where("created_at >= ?", since) if since
      scope = scope.where("metadata->>'utm_source' = ?", @utm_source) if @utm_source.present?
      scope = scope.where("metadata->>'utm_medium' = ?", @utm_medium) if @utm_medium.present?
      scope = scope.where("metadata->>'utm_campaign' = ?", @utm_campaign) if @utm_campaign.present?
      scope
    end

    def scoped_deals
      scope = @workspace.deals
      scope = scope.where("created_at >= ?", since) if since
      if @utm_source.present? || @utm_medium.present? || @utm_campaign.present?
        campaign_scope = @workspace.campaigns
        campaign_scope = campaign_scope.where(utm_source: @utm_source) if @utm_source.present?
        campaign_scope = campaign_scope.where(utm_medium: @utm_medium) if @utm_medium.present?
        campaign_scope = campaign_scope.where(utm_campaign: @utm_campaign) if @utm_campaign.present?
        scope = scope.where(campaign_id: campaign_scope.select(:id))
      end
      scope
    end

    def visit_keys
      scoped_page_views.group(:utm_source).count.keys.compact
    end

    def lead_keys
      scoped_leads.group(Arel.sql("metadata->>'utm_source'")).count.keys.compact
    end

    def deal_keys
      campaign_ids = scoped_deals.where.not(campaign_id: nil).select(:campaign_id)
      @workspace.campaigns.where(id: campaign_ids).distinct.pluck(:utm_source).compact
    end

    def visits_for(key)
      scoped_page_views.where(utm_source: key).count
    end

    def leads_for(key)
      scoped_leads.where("metadata->>'utm_source' = ?", key).count
    end

    def mqls_for(key)
      person_ids = scoped_leads.where("metadata->>'utm_source' = ?", key).select(:person_id)
      @workspace.people.where(id: person_ids, lifecycle_stage: MQL_STAGES).count
    end

    def deals_for(key)
      scoped_deals.where(campaign_id: @workspace.campaigns.where(utm_source: key).select(:id)).count
    end

    def revenue_for(key)
      scoped_deals.where(campaign_id: @workspace.campaigns.where(utm_source: key).select(:id)).sum(:value).to_f
    end
  end
end
