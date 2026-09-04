module Marketing
  class SendGuard
    def self.allowed?(workspace:, address:, subscription_type: nil)
      return false if EmailSuppression.suppressed?(workspace, address)
      return true unless subscription_type
      return true unless CreamFeatures.enabled?(:marketing_consent)

      person = workspace.people.with_email(address).first
      return false unless person

      subscription = EmailSubscription.find_by(person: person, subscription_type: subscription_type)
      subscription&.subscribed?
    end

    def self.filter_addresses(workspace:, addresses:, subscription_type: nil)
      addresses.map(&:to_s).map(&:strip).reject(&:blank?).uniq.select do |address|
        allowed?(workspace: workspace, address: address, subscription_type: subscription_type)
      end
    end
  end
end
