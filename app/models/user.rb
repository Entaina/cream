class User < ApplicationRecord
  has_secure_password
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

  THEMES = %w[light dark system].freeze

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :theme, inclusion: { in: THEMES }

  def self.organization_workspace_configured?
    ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"].present? &&
      ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"].present?
  end

  def self.organization_email?(email_address)
    return false unless organization_workspace_configured?

    domain = ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"].strip.downcase.delete_prefix("@")
    email_address.to_s.downcase.end_with?("@#{domain}")
  end

  DEMO_WORKSPACE_SLUG = "cream-demo"

  def self.provision_default_workspace!(user, workspace_name: nil)
    if organization_email?(user.email_address)
      org_workspace_name = ENV.fetch("CREAM_ORGANIZATION_WORKSPACE_NAME")
      workspace = Workspace.find_or_create_by!(slug: org_workspace_name.parameterize) do |record|
        record.name = org_workspace_name
      end
      role = workspace.memberships.exists? ? "salesperson" : "admin"
      workspace.memberships.create!(user: user, role: role)
    else
      workspace = Workspace.create!(name: workspace_name.presence || "#{user.name}'s Workspace")
      workspace.memberships.create!(user: user, role: "admin")
    end

    join_demo_workspace!(user)
    workspace
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
    email = auth.info.email
    name = auth.info.name

    user = find_by(provider: provider, uid: uid)
    unless user
      user = find_by(email_address: email)
      if user
        user.update!(provider: provider, uid: uid)
      else
        user = create!(
          name: name,
          email_address: email,
          password: SecureRandom.hex(32),
          provider: provider,
          uid: uid
        )
      end
    end

    if pending_invitation_token.present?
      invitation = Invitation.find_by_token(pending_invitation_token)
      if invitation&.pending? && invitation.email_address == user.email_address
        invitation.accept_for!(user)
        return user
      end
    end

    if user.workspaces.none?
      provision_default_workspace!(user)
    end

    user
  end

  def initials
    name.split.first(2).map { |w| w[0] }.join.upcase.presence || email_address[0].upcase
  end

  def default_workspace = workspaces.order(:id).first

  def active_workspace(session_workspace_id: nil)
    if session_workspace_id.present?
      workspace = workspaces.find_by(id: session_workspace_id)
      return workspace if workspace
    end

    default_workspace
  end

  def self.sidebar_default_keys
    base = %w[dashboard people companies deals products tasks]
    feature_keys = CreamFeatures.menu_entries.keys.map(&:to_s)
    base + feature_keys + %w[pipelines api_tokens profile team custom_fields]
  end

  def sidebar_order
    saved = sidebar_prefs["order"]
    return self.class.sidebar_default_keys if saved.blank?

    self.class.merge_sidebar_order(saved, self.class.sidebar_default_keys)
  end

  def sidebar_hidden
    Array(sidebar_prefs["hidden"]).map(&:to_s) & self.class.sidebar_default_keys
  end

  def update_sidebar_prefs!(order:, hidden:)
    known = self.class.sidebar_default_keys
    merged_order = self.class.merge_sidebar_order(order, known)
    valid_hidden = hidden.map(&:to_s) & known

    update!(sidebar_prefs: { "order" => merged_order, "hidden" => valid_hidden.uniq })
  end

  def self.merge_sidebar_order(saved_order, default_keys)
    saved = saved_order.map(&:to_s).select { |key| default_keys.include?(key) }.uniq
    missing = default_keys.reject { |key| saved.include?(key) }
    saved + missing
  end
end
