module Marketing
  class MqlToSqlConverter
    Result = Data.define(:status, :deal, :interest, :message)

    STATUSES = %w[created linked already_converted conflict invalid].freeze

    def self.call(interest:, actor:, attributes:)
      new(interest:, actor:, attributes:).call
    end

    def initialize(interest:, actor:, attributes:)
      @interest = interest
      @actor = actor
      @attributes = attributes.to_h.stringify_keys
      @workspace = interest.workspace
      @person = interest.person
      @product = interest.product
    end

    def call
      return invalid("Person is not marketing eligible") unless MqlEligibility.eligible?(person)

      ActiveRecord::Base.transaction do
        person.lock!
        interest.lock!

        interest.reload
        return already_converted_result if interest.converted?
        return invalid("Interest is not pending") unless interest.pending?

        existing = resolve_existing_open_deal
        return existing if existing.is_a?(Result)

        create_deal_from_interest!
      end
    rescue ActiveRecord::RecordInvalid => e
      invalid(e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :interest, :actor, :attributes, :workspace, :person, :product

    def already_converted_result
      deal = interest.deal
      return conflict("Converted deal is no longer accessible") if deal && !deal_policy(deal).show?
      return conflict("Interest already converted with different parameters") if incompatible_retry?

      Result.new(status: "already_converted", deal: deal, interest: interest, message: "Interest already converted")
    end

    def resolve_existing_open_deal
      deals = open_deals_for_product.to_a
      return nil if deals.empty?

      if attributes["deal_id"].present?
        chosen = deals.find { |deal| deal.id == attributes["deal_id"].to_i }
        return conflict("Selected opportunity is not valid for this product") unless chosen

        return link_to_existing_deal!(chosen)
      end

      visible = deals.select { |deal| deal_policy(deal).show? }
      case visible.size
      when 0
        conflict("An open opportunity exists but is not accessible")
      when 1
        link_to_existing_deal!(visible.first)
      else
        conflict("Multiple open opportunities exist; select one explicitly")
      end
    end

    def open_deals_for_product
      workspace.deals.open_deals
        .joins(:deal_products, :deal_contacts)
        .where(deal_products: {product_id: product.id}, deal_contacts: {person_id: person.id})
    end

    def incompatible_retry?
      snapshot = interest.metadata.fetch("conversion_snapshot", {})
      stored = snapshot["conversion_intent"]
      return false if stored.blank?

      normalized_conversion_intent != stored.stringify_keys
    end

    def normalized_conversion_intent
      {
        "pipeline_id" => attributes["pipeline_id"].to_s.presence,
        "deal_id" => attributes["deal_id"].to_s.presence,
        "task_title" => attributes["task_title"].to_s.presence,
        "task_due_on" => attributes["task_due_on"].to_s.presence
      }.compact
    end

    def deal_policy(deal)
      DealPolicy.new(UserContext.new(user: actor, workspace: workspace), deal)
    end

    def link_to_existing_deal!(deal)
      unless deal_policy(deal).update?
        return conflict("An open opportunity exists but is not accessible")
      end

      mark_interest_converted!(deal:, linked: true)
      cancel_nurturing_journeys!(deal)
      Result.new(status: "linked", deal: deal, interest: interest.reload, message: "Linked to existing opportunity")
    end

    def create_deal_from_interest!
      pipeline = workspace.pipelines.find(attributes["pipeline_id"])
      stage = pipeline.pipeline_stages.where(closed: false).ordered.first
      raise ActiveRecord::RecordInvalid.new(Deal.new) if stage.nil?

      task_attrs = {
        title: attributes.fetch("task_title"),
        due_on: Date.parse(attributes.fetch("task_due_on")),
        workspace: workspace,
        user: actor,
        assignee: resolve_assignee
      }

      deal = workspace.deals.create!(
        name: attributes["name"].presence || default_deal_name,
        company: person.company,
        pipeline: pipeline,
        pipeline_stage: stage,
        owner: attributes["owner_id"].presence ? workspace.users.find(attributes["owner_id"]) : actor,
        contacts: [person],
        tasks: [Task.new(task_attrs)],
        deal_products: [DealProduct.new(product: product, quantity: 1)],
        campaign_id: resolve_campaign_id
      )

      mark_interest_converted!(deal:, linked: false)
      record_conversion_context!(deal, linked: false)
      cancel_nurturing_journeys!(deal)
      Marketing::SegmentWatcher.sync_person!(person)

      Result.new(status: "created", deal: deal, interest: interest.reload, message: "Opportunity created")
    end

    def mark_interest_converted!(deal:, linked:)
      interest.update!(
        status: "converted",
        deal: deal,
        converted_at: Time.current,
        converted_by: actor,
        metadata: interest.metadata.merge(
          "conversion_snapshot" => conversion_snapshot(linked: linked)
        )
      )
    end

    def record_conversion_context!(deal, linked:)
      metadata = conversion_snapshot(linked: linked).merge("interest_id" => interest.id)
      person.track_activity("mql_converted", user: actor, metadata: metadata) if person.respond_to?(:track_activity)
      deal.track_activity(linked ? "mql_linked" : "mql_converted", user: actor, metadata: metadata) if deal.respond_to?(:track_activity)
    end

    def conversion_snapshot(linked:)
      {
        "linked" => linked,
        "product_id" => product.id,
        "product_name" => product.name,
        "signal" => interest.description,
        "source_kind" => interest.source_kind,
        "occurred_at" => interest.occurred_at.iso8601,
        "person_source" => person.source,
        "lifecycle_stage" => person.lifecycle_stage,
        "lead_score" => person.lead_score,
        "lead_submission_id" => interest.lead_submission_id,
        "conversion_intent" => normalized_conversion_intent
      }
    end

    def default_deal_name
      [person.company.name, product.name].compact.join(" — ")
    end

    def resolve_assignee
      id = attributes["task_assignee_id"].presence || actor.id
      workspace.users.find(id)
    end

    def resolve_campaign_id
      submission = interest.lead_submission
      return unless submission&.campaign_id.present?

      submission.campaign_id if workspace.campaigns.exists?(id: submission.campaign_id)
    end

    def cancel_nurturing_journeys!(deal)
      JourneyExit.cancel_for_open_deal!(person: person, product: product, deal: deal)
    end

    def invalid(message)
      Result.new(status: "invalid", deal: nil, interest: interest, message: message)
    end

    def conflict(message)
      Result.new(status: "conflict", deal: nil, interest: interest, message: message)
    end
  end
end
