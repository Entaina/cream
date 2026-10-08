module Public
  # Serves files from an offer ZIP via a signed token (no session cookie). Sandboxed origin allows JS
  # without access to the CRM session.
  class OfferPackagesController < ApplicationController
    allow_unauthenticated_access only: :show
    skip_forgery_protection only: :show
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    PACKAGE_CSP = "sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox allow-modals allow-presentation; " \
                  "default-src * data: blob: 'unsafe-inline' 'unsafe-eval'; " \
                  "script-src * data: blob: 'unsafe-inline' 'unsafe-eval'; form-action 'none'".freeze

    def show
      version = OfferVersion.find_signed!(params[:token], purpose: :offer_package)
      return head :not_found unless version.zip? && version.file.attached?

      path = normalized_path(params[:path])
      return head :not_found if path.blank?

      content = OfferPackage.read(version.file.blob, path)
      return head :not_found if content.nil?

      if OfferPackage.html_file?(path)
        content = OfferPackage.rewrite_html_for_preview(
          content,
          entry_path: path,
          base_href: package_base_href(version, path)
        )
      end

      apply_package_headers
      send_data content,
        type: OfferPackage.content_type_for(path),
        disposition: "inline",
        filename: File.basename(path)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def normalized_path(raw)
      path = Array(raw).join("/").delete_prefix("/")
      return nil if path.blank? || path.include?("..")

      path = "#{path}index.html" if path.end_with?("/")
      path
    end

    def package_base_href(version, path)
      dir = File.dirname(path)
      asset_path = dir == "." ? "" : "#{dir}/"
      offer_package_file_url(token: version.package_token, path: asset_path)
    end

    def apply_package_headers
      response.headers["Content-Security-Policy"] = PACKAGE_CSP
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["Access-Control-Allow-Origin"] = "*"
      response.headers["Cache-Control"] = "private, max-age=3600"
    end
  end
end
