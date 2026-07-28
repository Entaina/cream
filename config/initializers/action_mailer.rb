Rails.application.config.after_initialize do
  from = ENV.fetch("MAILER_FROM", "Cream <noreply@example.com>")
  ActionMailer::Base.default from: from
end
