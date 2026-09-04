# Register on each reload. `register_interceptor` skips duplicates of the same class.
Rails.application.config.to_prepare do
  ActionMailer::Base.register_interceptor(MailjetDeliveryInterceptor)
end
