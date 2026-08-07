require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  app_url = ENV.fetch("CREAM_APP_URL", "https://example.com")
  app_uri = URI.parse(app_url)
  config.action_mailer.default_url_options = {
    host: app_uri.host,
    protocol: app_uri.scheme,
    port: app_uri.port
  }

  # SMTP settings are resolved at runtime so the production assets:precompile
  # during `docker build` (run with SECRET_KEY_BASE_DUMMY=1) does not require
  # the real mailer credentials, which only exist on the deploy machine.
  # Assign to ActionMailer::Base as well: updating only config.action_mailer after
  # initialize leaves Base on the defaults (localhost:25) and deliveries fail.
  config.after_initialize do
    unless ENV["SECRET_KEY_BASE_DUMMY"]
      settings = {
        address: ENV.fetch("SMTP_ADDRESS"),
        port: ENV.fetch("SMTP_PORT", "587").to_i,
        user_name: ENV.fetch("SMTP_USERNAME"),
        password: ENV.fetch("SMTP_PASSWORD"),
        domain: ENV.fetch("SMTP_DOMAIN", app_uri.host),
        authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
        enable_starttls_auto: true
      }
      config.action_mailer.smtp_settings = settings
      ActionMailer::Base.smtp_settings = settings
    end
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
