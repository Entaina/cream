class BeehiivConnection < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  before_validation :assign_webhook_token, on: :create

  validates :workspace_id, uniqueness: true
  validates :webhook_token, presence: true, uniqueness: true
  validates :api_key, :publication_id, presence: true
  validates :publication_id, format: { with: /\Apub_[0-9a-fA-F\-]+\z/ }

  def connected? = api_key.present? && publication_id.present?

  def masked_api_key
    mask(api_key)
  end

  def webhook_url
    Rails.application.routes.url_helpers.public_beehiiv_webhook_url(
      token: webhook_token,
      **Marketing::LinkRewriter.tracking_url_options
    )
  end

  private

  def assign_webhook_token
    self.webhook_token ||= SecureRandom.urlsafe_base64(32)
  end

  def mask(value)
    return "" if value.blank?
    return "…" if value.length < 8

    "#{value.first(4)}…#{value.last(4)}"
  end
end
