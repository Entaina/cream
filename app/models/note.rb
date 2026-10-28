class Note < ApplicationRecord
  include WorkspaceScopedAssociations

  belongs_to :workspace
  belongs_to :notable, polymorphic: true
  belongs_to :user

  validates :body, presence: true
  validates_polymorphic_same_workspace :notable

  after_create :track_on_record

  private

  def track_on_record
    notable.track_activity("note_added", user: user, metadata: {note_id: id, title: title}) if notable.respond_to?(:track_activity)
  end
end
