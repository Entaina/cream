class EmailTrackingController < ApplicationController
  allow_unauthenticated_access only: %i[open click]
  skip_before_action :set_current_workspace, :ensure_workspace_membership
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def open
    message = EmailMessage.find_by(tracking_token: params[:token])
    message&.track_open!
    send_data transparent_gif, type: "image/gif", disposition: "inline"
  end

  def click
    unless CreamFeatures.enabled?(:email_tracking)
      head :not_found
      return
    end

    message = EmailMessage.find_by!(tracking_token: params[:token])
    message.track_click!
    redirect_to_click_target(message, params[:url], params[:sig])
  end

  private

  # Click tracking legitimately redirects to external links, but only allow
  # absolute http(s) URLs so the endpoint can't be abused for javascript:/data:
  # redirects. Anything else falls back to the app root. Destinations that are
  # neither signed nor present in the sent email get a confirmation page
  # instead of a silent redirect, so old emails never end up with dead links.
  def redirect_to_click_target(message, url, sig)
    return redirect_to root_path if url.blank?

    uri = URI.parse(url)
    unless uri.scheme&.downcase&.in?(%w[http https])
      return redirect_to root_path
    end

    if Marketing::LinkRewriter.valid_signature?(message, url, sig) || sent_destination?(message, url)
      head :found, location: url
    else
      Rails.logger.warn("[email_tracking] Unverified click target for EmailMessage##{message.id}: #{url}")
      @destination = url
      @destination_host = uri.host
      render :leaving, layout: "public_document"
    end
  rescue URI::InvalidURIError
    redirect_to root_path
  end

  # Emails sent before destinations were signed carry no sig. Rebuild the
  # destinations their links were rewritten to; if the campaign utm params
  # changed since, compare without utm_* on both sides.
  def sent_destination?(message, url)
    sent = Marketing::LinkRewriter.destinations(html: message.body, campaign: message.campaign)
    return true if sent.include?(url)

    stripped = url_without_utm_params(url)
    sent.any? { |destination| url_without_utm_params(destination) == stripped }
  end

  def url_without_utm_params(url)
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query.to_s).reject { |key, _| key.start_with?("utm_") }
    uri.query = params.any? ? URI.encode_www_form(params) : nil
    uri.to_s
  rescue URI::InvalidURIError, ArgumentError
    url
  end

  def transparent_gif
    Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==")
  end
end
