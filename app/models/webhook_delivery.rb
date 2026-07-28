class WebhookDelivery < ApplicationRecord
  belongs_to :webhook

  validates :event, presence: true
  validates :status, inclusion: { in: %w[pending delivered failed] }
end
