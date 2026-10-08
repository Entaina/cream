class ClientPortalLoginGrant < ApplicationRecord
  include OneTimeGrant

  EXPIRY = 30.minutes
  MAX_PER_EMAIL_PER_HOUR = 5

  belongs_to :workspace

  def self.issue!(workspace:, email:)
    build_with_token(workspace: workspace, email: OfferAccessGrant.normalize_email(email))
  end

  def self.consume!(workspace:, raw_token:)
    consume_from(where(workspace_id: workspace.id), raw_token)
  end

  def self.limit_reached?(workspace:, email:)
    where(workspace_id: workspace.id, email: OfferAccessGrant.normalize_email(email))
      .where("created_at > ?", 1.hour.ago).count >= MAX_PER_EMAIL_PER_HOUR
  end
end
