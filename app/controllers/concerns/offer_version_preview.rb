# Renders an OfferVersion for in-browser preview (PDF inline, HTML sandboxed, ZIP via signed package URL).
module OfferVersionPreview
  extend ActiveSupport::Concern

  # Sandbox: the offer is arbitrary user-supplied HTML served from the app's
  # origin, so it must never run scripts or reach the user's session.
  PREVIEW_CSP = "sandbox; default-src 'none'; img-src * data:; style-src * 'unsafe-inline'; font-src * data:"

  private

  def render_offer_version(version)
    if version.pdf?
      send_data version.file.download, type: "application/pdf", disposition: "inline", filename: version.file.filename.to_s
    elsif version.zip?
      redirect_to offer_package_file_path(token: version.package_token, path: version.entry_path)
    else
      response.headers["Content-Security-Policy"] = PREVIEW_CSP
      render body: version.html_content, content_type: "text/html"
    end
  end
end
