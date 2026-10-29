class SignupForbiddenError < StandardError; end

class User < ApplicationRecord
  include IanaTimeZone

  EMAIL_VERIFICATION_EXPIRES_IN = 2.days

  has_secure_password
  generates_token_for :email_verification, expires_in: EMAIL_VERIFICATION_EXPIRES_IN do
    email_verified_at&.to_i
  end

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :api_tokens, dependent: :destroy
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, dependent: :destroy
  has_many :saved_views, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :email_templates, dependent: :destroy
  has_many :gmail_connections, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :time_zone, with: ->(tz) { tz.presence }

  THEMES = %w[light dark system].freeze
  LOCALES = %w[es en].freeze

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :pending_workspace_name, length: {maximum: 255}, allow_blank: true
  validates :theme, inclusion: {in: THEMES}
  validates :locale, inclusion: {in: LOCALES}
  validates :password, length: {minimum: 8}, allow_nil: true

  after_update_commit :drop_support_memberships, if: -> { saved_change_to_superadmin?(to: false) }

  def self.organization_workspace_configured?
    ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"].present? &&
      ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"].present?
  end

  def self.organization_email?(email_address)
    return false unless organization_workspace_configured?

    domain = ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"].strip.downcase.delete_prefix("@")
    email_address.to_s.downcase.end_with?("@#{domain}")
  end

  def self.public_signup_enabled?
    fallback = Rails.env.production? ? "false" : "true"
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("CREAM_PUBLIC_SIGNUP", fallback))
  end

  def self.email_domain_from_address(email_address)
    email_address.to_s.downcase.split("@", 2).last
  end

  def self.workspace_for_email_domain(email_address)
    domain = email_domain_from_address(email_address)
    return if domain.blank?

    Workspace.find_by(email_domain: domain)
  end

  def self.allowed_to_register?(email_address, pending_invitation: nil)
    return true if public_signup_enabled?
    return true if pending_invitation&.pending?
    return true if workspace_for_email_domain(email_address).present?

    false
  end

  DEMO_WORKSPACE_SLUG = "cream-demo"

  def self.provision_default_workspace!(user, workspace_name: nil)
    domain_workspace = workspace_for_email_domain(user.email_address)
    workspace = if domain_workspace
      join_workspace_with_default_role!(user, domain_workspace)
      domain_workspace
    elsif organization_email?(user.email_address)
      org_workspace_name = ENV.fetch("CREAM_ORGANIZATION_WORKSPACE_NAME")
      org_workspace = Workspace.find_or_create_by!(slug: org_workspace_name.parameterize) do |record|
        record.name = org_workspace_name
      end
      join_workspace_with_default_role!(user, org_workspace)
      org_workspace
    elsif public_signup_enabled?
      personal = Workspace.create!(name: workspace_name.presence || "#{user.name}'s Workspace")
      personal.memberships.create!(user: user, role: "admin")
      personal
    else
      raise SignupForbiddenError
    end

    join_demo_workspace!(user) if public_signup_enabled?
    workspace
  end

  def self.join_workspace_with_default_role!(user, workspace)
    return if user.memberships.exists?(workspace: workspace)

    role = workspace.memberships.real_team.exists? ? "salesperson" : "admin"
    workspace.memberships.create!(user: user, role: role)
  end

  def self.join_demo_workspace!(user)
    demo = Workspace.find_by(slug: DEMO_WORKSPACE_SLUG)
    return unless demo

    demo.memberships.find_or_create_by!(user: user) do |membership|
      membership.role = "salesperson"
    end
  end

  def self.find_or_create_from_omniauth(auth, pending_invitation_token: nil)
    provider = auth.provider
    uid = auth.uid
    email = auth.info.email.to_s.strip.downcase
    name = auth.info.name
    raise SignupForbiddenError if email.blank?

    user = find_by(provider: provider, uid: uid)
    unless user
      raise SignupForbiddenError unless google_email_verified?(auth)

      user = find_by(email_address: email)
      if user
        link_oauth_identity!(user, provider:, uid:)
      else
        pending_invitation = Invitation.find_by_token(pending_invitation_token) if pending_invitation_token.present?
        unless allowed_to_register?(email, pending_invitation: pending_invitation)
          raise SignupForbiddenError
        end

        user = create!(
          name: name,
          email_address: email,
          password: SecureRandom.hex(32),
          provider: provider,
          uid: uid,
          email_verified_at: Time.current
        )
      end
    end

    if pending_invitation_token.present?
      invitation = Invitation.find_by_token(pending_invitation_token)
      if invitation&.pending? && invitation.email_address == user.email_address
        invitation.accept_for!(user)
        user.update!(pending_workspace_name: nil) if user.pending_workspace_name.present?
        return user
      end
    end

    if user.workspaces.none?
      provision_default_workspace!(user, workspace_name: user.pending_workspace_name)
      user.update!(pending_workspace_name: nil) if user.pending_workspace_name.present?
    end

    user
  end

  # Google has already checked the mailbox. An unverified password account may
  # have been created by someone else, so that password and its sessions must stop working.
  def self.link_oauth_identity!(user, provider:, uid:)
    if user.email_verified?
      user.update!(provider: provider, uid: uid)
    else
      transaction do
        user.update!(
          provider: provider,
          uid: uid,
          password: SecureRandom.hex(32),
          email_verified_at: Time.current
        )
        user.sessions.destroy_all
      end
    end
  end

  def email_verified?
    email_verified_at.present?
  end

  def email_verification_token
    generate_token_for(:email_verification)
  end

  def confirm_email_and_provision!
    transaction do
      self.email_verified_at ||= Time.current
      if workspaces.none? && self.class.allowed_to_register?(email_address)
        self.class.provision_default_workspace!(self, workspace_name: pending_workspace_name)
      end
      self.pending_workspace_name = nil
      save!
    end
    workspaces.reset
  end

  def initials
    name.split.first(2).map { |w| w[0] }.join.upcase.presence || email_address[0].upcase
  end

  def superadmin?
    superadmin
  end

  def ensure_superadmin_support_membership!(workspace)
    return unless superadmin?

    memberships.find_or_create_by!(workspace: workspace) do |membership|
      membership.role = "admin"
      membership.superadmin_access = true
    end
  end

  def default_workspace
    workspaces.order(:id).first || (superadmin? ? Workspace.order(:id).first : nil)
  end

  def effective_time_zone(workspace = Current.workspace)
    return time_zone if time_zone.present?

    workspace&.time_zone.presence || IanaTimeZone::DEFAULT_TIME_ZONE
  end

  def active_workspace(session_workspace_id: nil)
    if session_workspace_id.present?
      workspace = if superadmin?
        Workspace.find_by(id: session_workspace_id)
      else
        workspaces.find_by(id: session_workspace_id)
      end
      return workspace if workspace
    end

    default_workspace
  end

  def self.sidebar_default_keys(admin: true)
    SidebarMenu.default_keys(admin: admin)
  end

  def sidebar_default_keys(admin: true)
    self.class.sidebar_default_keys(admin: admin)
  end

  def sidebar_order(admin: true)
    known = sidebar_default_keys(admin: admin)
    saved = sidebar_prefs["order"]
    return known if saved.blank?

    self.class.merge_sidebar_order(saved, known)
  end

  def sidebar_hidden(admin: true)
    Array(sidebar_prefs["hidden"]).map(&:to_s) & sidebar_default_keys(admin: admin)
  end

  def update_sidebar_prefs!(order:, hidden:, admin: true)
    known = sidebar_default_keys(admin: admin)
    merged_order = self.class.merge_sidebar_order(order, known)
    valid_hidden = hidden.map(&:to_s) & known

    update!(sidebar_prefs: {"order" => merged_order, "hidden" => valid_hidden.uniq})
  end

  def self.merge_sidebar_order(saved_order, default_keys)
    SidebarMenu.merge_order(saved_order, default_keys)
  end

  def self.google_email_verified?(auth)
    raw = auth.extra&.raw_info
    if raw.respond_to?(:email_verified)
      return ActiveModel::Type::Boolean.new.cast(raw.email_verified)
    end
    if raw.is_a?(Hash)
      return ActiveModel::Type::Boolean.new.cast(raw["email_verified"])
    end

    false
  end

  private

  def drop_support_memberships
    memberships.where(superadmin_access: true).destroy_all
  end
end
