class PrivacyPolicyVersion < ApplicationRecord
  POLICY_PATH = "public/lead_forms/privacy".freeze
  IMMUTABLE_ATTRIBUTES = %w[content_hash policy_path policy_content statement_content workspace_id].freeze

  belongs_to :workspace
  has_many :lead_submissions, dependent: :nullify

  validates :content_hash, :policy_path, :policy_content, :statement_content, presence: true
  validates :content_hash, uniqueness: {scope: :workspace_id}
  validate :immutable_content, on: :update

  def self.find_by_hash!(workspace, hash)
    workspace.privacy_policy_versions.find_by!(content_hash: hash)
  end

  private

  def immutable_content
    return unless persisted?

    IMMUTABLE_ATTRIBUTES.each do |attribute|
      next unless will_save_change_to_attribute?(attribute)

      errors.add(attribute, "cannot be changed")
    end
  end
end
