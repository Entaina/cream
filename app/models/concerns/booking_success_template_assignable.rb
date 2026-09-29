module BookingSuccessTemplateAssignable
  extend ActiveSupport::Concern

  included do
    belongs_to :success_template, class_name: "LeadFormTemplate", optional: true
    validate :success_template_must_be_booking_page
  end

  private

  def success_template_must_be_booking_page
    return if success_template.nil?

    workspace_id = booking_success_template_workspace_id
    return if workspace_id.present? &&
      success_template.workspace_id == workspace_id &&
      success_template.booking? &&
      !success_template.partial?

    errors.add(:success_template, I18n.t("booking.errors.success_template_invalid"))
  end

  def booking_success_template_workspace_id
    if is_a?(BookingPage)
      workspace_id
    elsif is_a?(BookingEventType)
      booking_page&.workspace_id
    end
  end
end
