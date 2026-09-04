class EmailSuppression < ApplicationRecord
  REASONS = %w[unsubscribe hard_bounce spam_complaint manual].freeze

  belongs_to :workspace

  validates :address, :reason, presence: true
  validates :address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :reason, inclusion: { in: REASONS }
  validates :address, uniqueness: { scope: :workspace_id, case_sensitive: false }

  before_validation :normalize_address

  def self.suppress!(workspace:, address:, reason:, metadata: {})
    normalized = address.to_s.strip.downcase
    return if normalized.blank?

    find_or_create_by!(workspace: workspace, address: normalized) do |record|
      record.reason = reason
      record.metadata = metadata.stringify_keys
    end
  end

  def self.suppressed?(workspace, address)
    normalized = address.to_s.strip.downcase
    return false if normalized.blank?

    workspace.email_suppressions.exists?(address: normalized)
  end

  private

  def normalize_address
    self.address = address.to_s.strip.downcase if address.present?
  end
end
