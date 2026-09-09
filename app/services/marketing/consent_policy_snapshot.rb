module Marketing
  class ConsentPolicySnapshot
    def self.digest(policy_html:, statement_html:)
      policy_norm = normalize_html(policy_html)
      statement_norm = normalize_html(statement_html)
      Digest::SHA256.hexdigest([ policy_norm, statement_norm ].join("\x00"))
    end

    def self.capture(workspace:, policy_html:, statement_html:, policy_path: PrivacyPolicyVersion::POLICY_PATH)
      content_hash = digest(policy_html: policy_html, statement_html: statement_html)

      workspace.privacy_policy_versions.find_or_create_by!(content_hash: content_hash) do |version|
        version.policy_path = policy_path
        version.policy_content = policy_html.to_s
        version.statement_content = statement_html.to_s
      end
    end

    def self.normalize_html(html)
      return "" if html.blank?

      Nokogiri::HTML.fragment(html.to_s).text.squish
    end
    private_class_method :normalize_html
  end
end
