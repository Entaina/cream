module Marketing
  class LinkRewriter
    HREF_PATTERN = /href=(["'])([^"']+)\1/i

    def self.rewrite(html:, message:, campaign: nil)
      return html if html.blank?

      html.gsub(HREF_PATTERN) do
        quote = Regexp.last_match(1)
        url = Regexp.last_match(2)
        next "href=#{quote}#{url}#{quote}" if skip_url?(url)

        destination = append_utm(url, campaign)
        tracked = Rails.application.routes.url_helpers.email_tracking_click_url(
          **tracking_url_options,
          token: message.tracking_token,
          url: destination,
          sig: sign_destination(message, destination)
        )
        "href=#{quote}#{tracked}#{quote}"
      end
    end

    # Click destinations that rewrite produces for the links in html.
    def self.destinations(html:, campaign: nil)
      html.to_s.scan(HREF_PATTERN).map(&:last).reject { |url| skip_url?(url) }.map { |url| append_utm(url, campaign) }
    end

    def self.sign_destination(message, url)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{message.id}:#{url}")
    end

    def self.valid_signature?(message, url, sig)
      sig.present? && ActiveSupport::SecurityUtils.secure_compare(sign_destination(message, url), sig.to_s)
    end

    def self.tracking_url_options
      base = ENV.fetch("CREAM_APP_URL", "http://example.com")
      uri = URI.parse(base)
      options = {host: uri.host, protocol: uri.scheme}
      options[:port] = uri.port unless uri.port.in?([uri.default_port, 80, 443])
      options
    end

    def self.append_utm(url, campaign)
      return url unless campaign

      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query.to_s)
      campaign.utm_params.each { |key, value| params << [key, value] if value.present? }
      uri.query = URI.encode_www_form(params) if params.any?
      uri.to_s
    rescue URI::InvalidURIError
      url
    end

    def self.skip_url?(url)
      url.start_with?("#", "mailto:", "tel:", "javascript:")
    end
    private_class_method :skip_url?, :append_utm
  end
end
