# frozen_string_literal: true

module I18nHelper
  def blank_error_for(model_class, attribute)
    record = model_class.new
    record.errors.add(attribute, :blank)
    record.errors.full_messages_for(attribute).first
  end

  def taken_error_for(model_class, attribute)
    record = model_class.new
    record.errors.add(attribute, :taken)
    record.errors.full_messages_for(attribute).first
  end

  def not_authorized_message
    I18n.t("auth.flashes.not_authorized")
  end
end

RSpec.configure do |config|
  config.include I18nHelper
  config.after { I18n.locale = I18n.default_locale }
end
