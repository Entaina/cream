class Comment < ApplicationRecord
  COMMENTABLE_TYPES = %w[Company Person Deal].freeze

  belongs_to :workspace
  belongs_to :commentable, polymorphic: true
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true
  validate :commentable_type_allowed

  after_create :track_on_record
  after_create :notify_mentions

  scope :top_level, -> { where(parent_id: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def mentioned_users
    MentionParser.users_from(body, workspace: workspace)
  end

  private

  def commentable_type_allowed
    return if COMMENTABLE_TYPES.include?(commentable_type)

    errors.add(:commentable_type, :commentable_not_allowed)
  end

  def track_on_record
    return unless commentable.respond_to?(:track_activity)

    commentable.track_activity("comment_added", user: user, metadata: {comment_id: id})
  end

  def notify_mentions
    mentioned_users.each do |mentioned|
      next if mentioned.id == user_id

      NotificationService.notify_mention(
        recipient: mentioned,
        actor: user,
        comment: self
      )
    end
  end
end
