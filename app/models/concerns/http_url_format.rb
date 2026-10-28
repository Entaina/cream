module HttpUrlFormat
  extend ActiveSupport::Concern

  SCHEME = /\A[a-z][a-z0-9+.\-]*:/i
  BARE_DOMAIN = /\A[\w-]+(\.[\w-]+)+([\/?#]|\z)/

  class_methods do
    def validates_http_url(*attributes)
      before_validation do
        attributes.each do |attribute|
          value = public_send(attribute).to_s.strip
          next if value.blank? || value.match?(SCHEME) || !value.match?(BARE_DOMAIN)

          public_send(:"#{attribute}=", "https://#{value}")
        end
      end

      validates_each attributes do |record, attribute, value|
        next if value.blank?

        uri = URI.parse(value.to_s)
        unless uri.is_a?(URI::HTTP) && uri.host.present?
          record.errors.add(attribute, :invalid)
        end
      rescue URI::InvalidURIError
        record.errors.add(attribute, :invalid)
      end
    end
  end
end
