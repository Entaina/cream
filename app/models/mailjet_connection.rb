class MailjetConnection < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  encrypts :api_key, :secret_key

  before_validation :assign_webhook_token, on: :create

  validates :workspace_id, uniqueness: true
  validates :webhook_token, presence: true, uniqueness: true
  validates :api_key, :secret_key, :from_email, presence: true
  validates :from_email, format: {with: URI::MailTo::EMAIL_REGEXP}

  def connected? = api_key.present? && secret_key.present?

  def transactional? = connected? && transactional_enabled?

  def masked_api_key
    mask(api_key)
  end

  def masked_secret_key
    mask(secret_key)
  end

  def webhook_url
    Rails.application.routes.url_helpers.public_email_events_url(
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
