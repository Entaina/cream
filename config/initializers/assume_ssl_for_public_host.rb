# When CREAM_APP_URL is HTTPS (e.g. ngrok), only treat requests to that public host
# as SSL. Accessing http://localhost:$PORT must keep non-secure cookies or OmniAuth
# CSRF verification fails (InvalidAuthenticityToken).
if Rails.env.development?
  public_app_url = ENV["CREAM_APP_URL"]
  if public_app_url&.start_with?("https://")
    public_host = URI.parse(public_app_url).host

    class AssumeSslForPublicHost
      def initialize(app, public_host:)
        @app = app
        @public_host = public_host
      end

      def call(env)
        request_host = env["HTTP_HOST"]&.split(":")&.first
        if request_host == @public_host
          env["HTTPS"] = "on"
          env["rack.url_scheme"] = "https"
        end

        @app.call(env)
      end
    end

    Rails.application.config.middleware.insert_before 0, AssumeSslForPublicHost, public_host: public_host
  end
end
