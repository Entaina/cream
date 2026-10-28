# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src :self, :https, :data
    policy.img_src :self, :https, :data, :blob
    policy.object_src :none
    policy.script_src :self, "https://challenges.cloudflare.com"
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self, :https, :wss
    policy.frame_src :self, "https://challenges.cloudflare.com"
    policy.base_uri :self
    policy.report_uri "/csp_reports"
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Violations are only reported (see "[CSP]" lines in the log) until they are fixed.
  config.content_security_policy_report_only = true
end
