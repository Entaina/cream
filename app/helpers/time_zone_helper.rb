# frozen_string_literal: true

module TimeZoneHelper
  # Formats a UTC instant in a fixed IANA zone (ignores the request/user Time.zone).
  def l_in_time_zone(time, zone_name, **options)
    return "—" if time.blank?

    zone = ActiveSupport::TimeZone[zone_name.presence] || Time.zone
    I18n.l(time.in_time_zone(zone), **options)
  end

  def time_zone_options(selected: nil, include_blank: false, blank_label: nil)
    zones = ActiveSupport::TimeZone.all.map { |zone| [zone.to_s, zone.tzinfo.name] }.uniq(&:last)
    if include_blank
      blank_text = blank_label || t("profile.time_zone_blank", workspace_zone: IanaTimeZone::DEFAULT_TIME_ZONE)
      zones = [[blank_text, ""]] + zones
    end
    options_for_select(zones, selected)
  end
end
