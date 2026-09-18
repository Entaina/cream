# frozen_string_literal: true

module IanaTimeZone
  extend ActiveSupport::Concern

  DEFAULT_TIME_ZONE = "Europe/Madrid"

  def self.canonical(value)
    ActiveSupport::TimeZone[value]&.tzinfo&.name
  end

  def self.valid_iana_time_zone?(value)
    canonical(value).present?
  end

  class_methods do
    def valid_iana_time_zone?(value)
      IanaTimeZone.valid_iana_time_zone?(value)
    end

    def canonical(value)
      IanaTimeZone.canonical(value)
    end
  end

  included do
    validate :time_zone_must_be_valid_iana, if: -> { respond_to?(:time_zone) && time_zone.present? }
  end

  private

  def time_zone_must_be_valid_iana
    return if IanaTimeZone.valid_iana_time_zone?(time_zone)

    errors.add(:time_zone, :invalid)
  end
end
