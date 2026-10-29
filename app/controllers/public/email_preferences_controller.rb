module Public
  class EmailPreferencesController < ApplicationController
    layout "public_lead_form"

    allow_unauthenticated_access only: %i[show update confirm_unsubscribe unsubscribe]
    # RFC 8058 one-click unsubscribe is a POST from the mail client, without session or
    # CSRF token; the signed preference token is the authorization.
    skip_forgery_protection only: :unsubscribe
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :ensure_feature_enabled
    before_action :set_person, except: :unsubscribe

    # Link scanners in mail servers follow GET links, so GET only asks for confirmation.
    def confirm_unsubscribe
      @workspace = @person.workspace
      @unsubscribe_params = {type: params[:type].presence, all: params[:all].presence}.compact
    end

    def show
      @workspace = @person.workspace
      SubscriptionType.ensure_defaults!(@workspace)
      @subscription_types = @workspace.subscription_types.active.ordered
      @subscriptions = EmailSubscription.where(person: @person, subscription_type: @subscription_types).index_by(&:subscription_type_id)
    end

    def update
      @workspace = @person.workspace
      SubscriptionType.ensure_defaults!(@workspace)
      selected_ids = Array(params[:subscription_type_ids]).map(&:to_i)

      @workspace.subscription_types.active.find_each do |type|
        if selected_ids.include?(type.id)
          Marketing::ConsentService.subscribe!(
            person: @person,
            subscription_type: type,
            source: "preference_center",
            legal_basis: "consent"
          )
        else
          Marketing::ConsentService.unsubscribe!(person: @person, subscription_type: type)
        end
      end

      redirect_to public_email_preferences_path(token: params[:token]), notice: t("flashes.email_preferences.updated")
    end

    def unsubscribe
      @person = Marketing::PreferenceToken.verify(params[:token])
      return head :not_found unless @person

      @workspace = @person.workspace
      SubscriptionType.ensure_defaults!(@workspace)

      if params[:all].present?
        Marketing::ConsentService.unsubscribe_all!(person: @person, source: "one_click_unsubscribe")
      else
        type = @workspace.subscription_types.find_by(slug: params[:type].presence || "newsletter") ||
          @workspace.subscription_types.active.first
        Marketing::ConsentService.unsubscribe!(person: @person, subscription_type: type) if type
      end
      render :unsubscribed
    end

    private

    def ensure_feature_enabled
      head :not_found unless CreamFeatures.enabled?(:marketing_consent)
    end

    def set_person
      @person = Marketing::PreferenceToken.verify(params[:token])
      head :not_found unless @person
    end
  end
end
