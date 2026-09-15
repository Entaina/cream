class Invitation < ApplicationRecord
  TOKEN_PREFIX = "inv_".freeze
  EXPIRES_IN = 7.days

  belongs_to :workspace
  belongs_to :invited_by, class_name: "User"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :role, inclusion: {in: Membership::ROLES}
  validates :token_digest, presence: true
  validate :email_not_already_member, on: :create
  validate :no_duplicate_pending_invitation, on: :create

  attr_reader :plaintext_token

  before_validation :generate_token, on: :create
  before_validation :set_expires_at, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }

  def self.find_by_token(plaintext)
    return nil if plaintext.blank?

    find_by(token_digest: digest(plaintext))
  end

  def self.digest(plaintext)
    OpenSSL::Digest::SHA256.hexdigest(plaintext)
  end

  def pending?
    accepted_at.nil? && !expired?
  end

  def role_label
    Membership::ROLE_LABELS.fetch(role, role)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def accept_for!(user)
    raise ActiveRecord::RecordInvalid, self unless pending?
    raise ActiveRecord::RecordInvalid, self unless email_address == user.email_address

    transaction do
      membership = workspace.memberships.find_by(user: user)
      if membership
        membership.update!(role: role) if membership.role != role
      else
        workspace.memberships.create!(user: user, role: role)
      end
      update!(accepted_at: Time.current)
    end
  end

  def accept_url(plaintext = plaintext_token)
    return nil if plaintext.blank?

    opts = Rails.application.config.action_mailer.default_url_options.symbolize_keys
    Rails.application.routes.url_helpers.accept_invitation_url(token: plaintext, **opts)
  end

  def regenerate_token!
    @plaintext_token = TOKEN_PREFIX + SecureRandom.urlsafe_base64(32)
    update!(
      token_digest: self.class.digest(@plaintext_token),
      expires_at: EXPIRES_IN.from_now
    )
  end

  private

  def generate_token
    return if token_digest.present?

    @plaintext_token = TOKEN_PREFIX + SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@plaintext_token)
  end

  def set_expires_at
    self.expires_at ||= EXPIRES_IN.from_now
  end

  def email_not_already_member
    return if email_address.blank? || workspace.blank?

    if workspace.users.exists?(email_address: email_address)
      errors.add(:email_address, "is already a member of this workspace")
    end
  end

  def no_duplicate_pending_invitation
    return if email_address.blank? || workspace.blank?

    if workspace.invitations.pending.exists?(email_address: email_address)
      errors.add(:email_address, "already has a pending invitation")
    end
  end
end
