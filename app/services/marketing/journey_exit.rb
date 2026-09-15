module Marketing
  class JourneyExit
    def self.cancel_for_open_deal!(person:, product:, deal:)
      return unless CreamFeatures.enabled?(:journeys)

      applicable_journeys(person.workspace, product).find_each do |journey|
        journey.enrollments.where(person: person, state: %w[active waiting]).find_each do |enrollment|
          enrollment.update!(
            state: "cancelled",
            metadata: enrollment.metadata.merge(
              "cancelled_reason" => "open_deal",
              "deal_id" => deal.id,
              "cancelled_at" => Time.current.iso8601
            )
          )
        end
      end
    end

    def self.blocked_by_open_deal?(person:, journey:)
      return false unless journey.stop_on_open_deal?
      return false if journey.product_id.blank?

      person.deals.open_deals
        .joins(:deal_products)
        .exists?(deal_products: {product_id: journey.product_id})
    end

    def self.applicable_journeys(workspace, product)
      workspace.journeys.active.where(stop_on_open_deal: true, product_id: product.id)
    end
    private_class_method :applicable_journeys
  end
end
