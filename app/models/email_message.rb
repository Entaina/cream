class EmailMessage < ApplicationRecord
  RECORD_TYPES = %w[Company Person Deal].freeze
  DIRECTIONS = %w[outbound inbound].freeze
  MAX_ATTACHMENTS = 10
  MAX_ATTACHMENT_SIZE = 10.megabytes
  MAX_TOTAL_ATTACHMENT_SIZE = 25.megabytes

  belongs_to :workspace
  belongs_to :user
  belongs_to :record, polymorphic: true
  belongs_to :in_reply_to, class_name: "EmailMessage", optional: true
  has_many :replies, class_name: "EmailMessage", foreign_key: :in_reply_to_id, dependent: :nullify, inverse_of: :in_reply_to

  has_many_attached :attachments

  validates :to_address, :subject, :body, presence: true
  validates :record_type, inclusion: { in: RECORD_TYPES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validate :to_address_format
  validate :attachments_within_limits

  before_create :assign_tracking_token

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :scheduled, -> { where(status: "scheduled") }
  scope :outbound, -> { where(direction: "outbound") }
  scope :inbound, -> { where(direction: "inbound") }

  def opened? = opened_at.present?

  def scheduled? = status == "scheduled"

  def failed? = status == "failed"

  def received? = status == "received"

  def inbound? = direction == "inbound"

  def outbound? = direction == "outbound"

  def replied? = replied_at.present?

  # A sent email with a pending follow-up the sender still needs to chase.
  def awaiting_follow_up? = follow_up_at.present? && replied_at.nil? && !scheduled? && outbound?

  # Whether this message should go out through the sender's connected Gmail
  # account instead of SMTP. Single source of truth so immediate and scheduled
  # (deferred) sends pick the same channel, evaluated at send time.
  def route_via_gmail?
    return false unless CreamFeatures.enabled?(:gmail_sync)

    connection = workspace.gmail_connections.find_by(user_id: user_id)
    !!(connection&.connected? && connection.send_enabled?)
  end

  def track_open!
    return if opened?
    return unless CreamFeatures.enabled?(:email_tracking)
    return if inbound?

    update!(opened_at: Time.current, status: "opened")
    record.track_activity("email_opened", user: user, metadata: { subject: subject, to: to_address }) if record.respond_to?(:track_activity)
    NotificationService.notify_email_opened(message: self) if CreamFeatures.enabled?(:notifications)
  end

  def track_sent!
    return if inbound?
    return unless record.respond_to?(:track_activity)
    return if sent_activity_recorded?

    record.track_activity(
      "email_sent",
      user: user,
      metadata: { subject: subject, to: to_address, email_message_id: id }
    )
    Ai::AutomationHooks.after_email_sent(message: self)
  end

  def track_click!
    return unless CreamFeatures.enabled?(:email_tracking)
    return if inbound?

    increment!(:clicks_count)
    record.track_activity("email_clicked", user: user, metadata: { subject: subject }) if record.respond_to?(:track_activity)
  end

  # Builds attachment payloads for outbound delivery (Gmail API or SMTP).
  def attachment_files
    attachments.map do |file|
      {
        filename: file.filename.to_s,
        content_type: file.content_type,
        content: file.download
      }
    end
  end

  private

  def assign_tracking_token
    self.tracking_token ||= SecureRandom.urlsafe_base64(24)
  end

  def to_address_format
    return if to_address.blank?
    return if to_address.match?(URI::MailTo::EMAIL_REGEXP)

    errors.add(:to_address, "is invalid")
  end

  def sent_activity_recorded?
    record.activities.exists?(["action = ? AND metadata->>'email_message_id' = ?", "email_sent", id.to_s])
  end

  def attachments_within_limits
    return unless attachments.attached?

    if attachments.count > MAX_ATTACHMENTS
      errors.add(:attachments, "cannot exceed #{MAX_ATTACHMENTS} files")
      return
    end

    total = 0
    attachments.each do |file|
      if file.byte_size > MAX_ATTACHMENT_SIZE
        errors.add(:attachments, "#{file.filename} exceeds #{MAX_ATTACHMENT_SIZE / 1.megabyte} MB")
      end
      total += file.byte_size
    end

    if total > MAX_TOTAL_ATTACHMENT_SIZE
      errors.add(:attachments, "total size cannot exceed #{MAX_TOTAL_ATTACHMENT_SIZE / 1.megabyte} MB")
    end
  end
end
