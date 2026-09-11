# frozen_string_literal: true

class LocalePreferencesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  allow_unauthenticated_access only: :update

  def update
    locale = params[:locale].presence_in(User::LOCALES)
    return head :unprocessable_entity unless locale

    persist_locale_cookie(locale)

    if current_user && !current_user.update(locale: locale)
      return head :unprocessable_entity
    end

    head :ok
  end
end
