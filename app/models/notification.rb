class Notification < ApplicationRecord
  KINDS = %w[mention task_overdue email_opened email_followup email_replied lead_submission booking booking_page_invite automation alert].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true

  validates :kind, inclusion: {in: KINDS}
  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def read? = read_at.present?

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
