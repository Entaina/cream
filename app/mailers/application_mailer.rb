class ApplicationMailer < ActionMailer::Base
  layout "mailer"
  helper EmailHelper
end
