# frozen_string_literal: true

module SetLocale
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    resume_session if respond_to?(:resume_session, true)
    I18n.locale = resolved_locale.to_sym
  end

  def resolved_locale
    locale = if current_user
      current_user.locale
    else
      cookies[:locale].presence || browser_locale
    end

    locale.to_s.presence_in(User::LOCALES) || I18n.default_locale.to_s
  end

  def browser_locale
    request.env["HTTP_ACCEPT_LANGUAGE"].to_s[/\A[a-z]{2}/]
  end

  def persist_locale_cookie(locale)
    valid_locale = locale.to_s.presence_in(User::LOCALES)
    return unless valid_locale

    cookies[:locale] = {value: valid_locale, expires: 1.year.from_now, same_site: :lax}
  end
end
