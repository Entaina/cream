class RecordAttachment < ApplicationRecord
  ATTACHABLE_TYPES = %w[Company Person Deal].freeze

  belongs_to :workspace
  belongs_to :attachable, polymorphic: true
  belongs_to :user

  has_one_attached :file

  validates :file, presence: true
  validate :attachable_type_allowed

  after_create :track_on_record

  def display_name
    name.presence || file.filename.to_s
  end

  private

  def attachable_type_allowed
    return if ATTACHABLE_TYPES.include?(attachable_type)

    errors.add(:attachable_type, "is not allowed")
  end

  def track_on_record
    return unless attachable.respond_to?(:track_activity)

    attachable.track_activity("attachment_added", user: user, metadata: {filename: display_name})
  end
end
