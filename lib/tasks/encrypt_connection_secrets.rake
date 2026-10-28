namespace :security do
  desc "Encrypt connection secrets stored in plaintext before Active Record Encryption was enabled"
  task encrypt_connection_secrets: :environment do
    scopes = [GmailConnection, CalendarConnection, MailjetConnection, StripeConnection, BeehiivConnection, SmtpConnection, Webhook].map(&:all)
    scopes << Workspace.where.not(okm_service_account_key: nil)

    scopes.each do |scope|
      count = 0
      # encrypt writes with update_columns: no validations, callbacks or updated_at changes.
      scope.find_each do |record|
        record.encrypt
        count += 1
      end
      puts "#{scope.model.name}: #{count}"
    end
  end
end
