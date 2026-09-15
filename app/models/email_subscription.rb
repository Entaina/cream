class EmailSubscription < ApplicationRecord
  STATUSES = %w[subscribed unsubscribed pending].freeze

  belongs_to :workspace
  belongs_to :person
  belongs_to :subscription_type

  validates :status, inclusion: {in: STATUSES}

  scope :subscribed, -> { where(status: "subscribed") }

  def subscribed?
    status == "subscribed"
  end

  def subscribe!(source:, legal_basis: nil, metadata: {})
    update!(
      status: "subscribed",
      opted_in_at: Time.current,
      opted_out_at: nil,
      source: source,
      legal_basis: legal_basis,
      metadata: self.metadata.merge(metadata.stringify_keys)
    )
  end

  def unsubscribe!(source: "preference_center", metadata: {})
    update!(
      status: "unsubscribed",
      opted_out_at: Time.current,
      source: source,
      metadata: self.metadata.merge(metadata.stringify_keys)
    )
  end
end
