class EmailTrackingController < ApplicationController
  allow_unauthenticated_access only: %i[open click]
  skip_before_action :set_current_workspace, :ensure_workspace_membership
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def open
    message = EmailMessage.find_by(tracking_token: params[:token])
    message&.track_open! if message
    send_data transparent_gif, type: "image/gif", disposition: "inline"
  end

  def click
    unless CreamFeatures.enabled?(:email_tracking)
      head :not_found
      return
    end

    message = EmailMessage.find_by!(tracking_token: params[:token])
    message.track_click!
    redirect_to_click_target(params[:url])
  end

  private

  # Click tracking legitimately redirects to external links, but only allow
  # absolute http(s) URLs so the endpoint can't be abused for javascript:/data:
  # redirects. Anything else falls back to the app root.
  def redirect_to_click_target(url)
    return redirect_to root_path if url.blank?

    uri = URI.parse(url)
    unless uri.scheme&.downcase.in?(%w[http https])
      return redirect_to root_path
    end

    head :found, location: url
  rescue URI::InvalidURIError
    redirect_to root_path
  end

  def transparent_gif
    Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==")
  end
end
