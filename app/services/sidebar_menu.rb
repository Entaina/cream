# frozen_string_literal: true

# Canonical sidebar structure: groups, item keys, and order merging.
module SidebarMenu
  GROUPS = {
    daily: { label: nil, collapsible: false, admin_only: false },
    marketing: { label: "Marketing", collapsible: true, admin_only: false },
    settings: { label: "Configuración", collapsible: true, admin_only: true },
    profile: { label: "Mi perfil", collapsible: true, admin_only: false }
  }.freeze

  CANONICAL_KEYS_BY_GROUP = {
    daily: %w[dashboard people companies deals tasks],
    marketing: %w[marketing_campaigns marketing_segments journeys marketing_attribution lead_scoring marketing_consent email_templates],
    settings: %w[team products pipelines custom_fields alerts automations lead_forms stripe_payments webhooks reports workspace],
    profile: %w[profile gmail_sync calendar_booking lists api_tokens]
  }.freeze

  def self.default_keys(admin: true)
    CANONICAL_KEYS_BY_GROUP.flat_map do |group, keys|
      next [] if GROUPS[group][:admin_only] && !admin

      keys
    end
  end

  def self.group_for(key)
    CANONICAL_KEYS_BY_GROUP.each do |group, keys|
      return group if keys.include?(key.to_s)
    end
    nil
  end

  def self.merge_order(saved_order, default_keys)
    saved = saved_order.map(&:to_s).select { |key| default_keys.include?(key) }.uniq

    CANONICAL_KEYS_BY_GROUP.flat_map do |_group, group_keys|
      visible = group_keys & default_keys
      ordered = saved.select { |key| visible.include?(key) }
      missing = visible - ordered
      ordered + missing
    end
  end

  def self.nav_groups(admin: true)
    GROUPS.filter_map do |key, meta|
      next if meta[:admin_only] && !admin

      { key: key, **meta, keys: CANONICAL_KEYS_BY_GROUP[key] & default_keys(admin: admin) }
    end
  end
end
