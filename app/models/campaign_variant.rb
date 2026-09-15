class CampaignVariant < ApplicationRecord
  belongs_to :campaign_send

  validates :name, :subject, :body, presence: true
  validates :weight, numericality: {greater_than: 0, less_than_or_equal_to: 100}

  def self.pick_for_email(variants, email)
    return nil if variants.blank?

    bucket = Digest::SHA256.hexdigest("#{variants.first.campaign_send_id}-#{email}")[0, 8].to_i(16) % 100
    cumulative = 0
    variants.each do |variant|
      cumulative += variant.weight
      return variant if bucket < cumulative
    end
    variants.last
  end
end
