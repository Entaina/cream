# frozen_string_literal: true

module SetTimeZone
  extend ActiveSupport::Concern

  included do
    around_action :set_time_zone
  end

  private

  def set_time_zone(&block)
    set_current_workspace if respond_to?(:set_current_workspace, true)
    Time.use_zone(resolved_time_zone, &block)
  end

  def resolved_time_zone
    if current_user
      current_user.effective_time_zone(current_workspace)
    elsif current_workspace
      current_workspace.time_zone.presence || IanaTimeZone::DEFAULT_TIME_ZONE
    else
      IanaTimeZone::DEFAULT_TIME_ZONE
    end
  end
end
