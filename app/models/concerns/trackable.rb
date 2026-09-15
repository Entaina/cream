# Records create/update events on the workspace activity timeline.
module Trackable
  extend ActiveSupport::Concern

  TRACKED_IGNORE = %w[id created_at updated_at position].freeze

  included do
    has_many :activities, as: :subject, dependent: :destroy
    after_create :track_created
    after_update :track_updated
  end

  def track_activity(action, user: Current.user, metadata: {})
    activities.create!(workspace: workspace, user: user, action: action, metadata: metadata)
  end

  # Attributes whose changes are reported through dedicated activity types.
  def tracked_ignored_attributes = []

  private

  def track_created
    track_activity("created")
  end

  def track_updated
    changes = saved_changes.except(*TRACKED_IGNORE, *tracked_ignored_attributes)
    return if changes.empty?

    track_activity("updated", metadata: {changes: changes.transform_values { |(from, to)| [from.to_s, to.to_s] }})
  end
end
