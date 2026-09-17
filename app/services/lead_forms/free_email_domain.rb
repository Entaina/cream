module LeadForms
  class FreeEmailDomain
    class << self
      def blocked?(email)
        domain = extract_domain(email)
        return false if domain.blank?

        domains.include?(domain)
      end

      def domains
        @domains ||= load_domains
      end

      def reload!
        @domains = nil
      end

      private

      def extract_domain(email)
        email.to_s.strip.downcase.split("@", 2).last
      end

      def load_domains
        path = Rails.root.join("config/free_email_domains.yml")
        data = YAML.load_file(path)
        Set.new(Array(data["domains"]).map { |d| d.to_s.strip.downcase }.reject(&:blank?))
      end
    end
  end
end
