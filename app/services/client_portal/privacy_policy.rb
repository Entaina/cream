module ClientPortal
  # The workspace privacy policy template (the one lead forms link to), rendered outside any lead form.
  class PrivacyPolicy
    def self.html(workspace)
      body = LeadFormTemplates::Source.find_body(workspace: workspace, path: PrivacyPolicyVersion::POLICY_PATH)
      return if body.blank?

      Liquid::Template.parse(body, environment: LeadFormTemplates::Renderer.build_environment).render({}).html_safe
    rescue Liquid::Error
      nil
    end

    def self.snapshot(workspace:, statement_html:)
      policy_html = html(workspace)
      return if policy_html.blank?

      Marketing::ConsentPolicySnapshot.capture(workspace: workspace, policy_html: policy_html, statement_html: statement_html)
    end
  end
end
