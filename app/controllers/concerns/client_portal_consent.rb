# Required subscriptions are checked before the one-time token is spent, so a missing tick keeps the link usable.
module ClientPortalConsent
  extend ActiveSupport::Concern

  private

  def load_consent_types(workspace, email)
    @consent_types = ClientPortal::ConsentOffer.types_for(workspace: workspace, email: email)
  end

  def required_consent_missing?
    ClientPortal::ConsentOffer.missing_required?(@consent_types, params[:consent_type_ids])
  end

  def render_required_consent_missing(template)
    flash.now[:alert] = t("client_portal.consent.required_missing")
    render template, status: :unprocessable_entity
  end
end
