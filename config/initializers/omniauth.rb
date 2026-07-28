require "omniauth/rails_csrf_protection"

# Avoid 500 when OAuth state is missing (session lost between redirect and callback).
module OmniAuthOAuth2SecureCompareNilFix
  def secure_compare(string_a, string_b)
    return false if string_a.nil? || string_b.nil?

    super
  end
end
OmniAuth::Strategies::OAuth2.prepend(OmniAuthOAuth2SecureCompareNilFix)

using_https_public_url = ENV["CREAM_APP_URL"]&.start_with?("https://")

if using_https_public_url
  secure_session = lambda do |env|
    req = Rack::Request.new(env)
    return unless req.ssl?

    env["rack.session.options"]["secure"] = true
    env["rack.session.options"]["same_site"] = :lax
  end

  OmniAuth.config.before_request_phase do |env|
    secure_session.call(env) if env["PATH_INFO"].in?(%w[/auth/google_oauth2 /auth/google_gmail])
  end

  OmniAuth.config.before_callback_phase do |env|
    secure_session.call(env) if env["PATH_INFO"].in?(%w[/auth/google_oauth2/callback /auth/google_gmail/callback])
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  # Sign-in: identity only.
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    scope: "email,profile"

  # Gmail connection: default scope is send-only; callers pass scope via request params
  # for send+metadata (incremental auth). Phase 2 (full body logging) will need
  # gmail.readonly (restricted scope — see deploy/GMAIL_SETUP.md).
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    name: "google_gmail",
    scope: [
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.send"
    ].join(","),
    access_type: "offline",
    prompt: "consent"
end

OmniAuth.config.allowed_request_methods = %i[post]
