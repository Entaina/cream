class BeehiivPublication < ApplicationRecord
  belongs_to :beehiiv_connection
  belongs_to :subscription_type

  delegate :workspace, to: :beehiiv_connection

  def workspace_id
    beehiiv_connection&.workspace_id
  end

  before_validation :assign_webhook_token, on: :create

  validates :publication_id, presence: true, format: {with: /\Apub_[0-9a-fA-F-]+\z/}
  validates :webhook_token, presence: true, uniqueness: true
  validates :publication_id, uniqueness: {scope: :beehiiv_connection_id}
  validates :subscription_type_id, uniqueness: {scope: :beehiiv_connection_id}
  validate :subscription_type_in_workspace

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

  def subscription_type_in_workspace
    return if subscription_type.blank? || beehiiv_connection.blank?
    return if subscription_type.workspace_id == beehiiv_connection.workspace_id

    errors.add(:subscription_type, :must_belong_to_same_workspace)
  end
end
