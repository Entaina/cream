class AlertDelivery < ApplicationRecord
  belongs_to :alert_rule
  belongs_to :deal
  belongs_to :user

  validates :deal_id, uniqueness: { scope: %i[alert_rule_id user_id] }
end
