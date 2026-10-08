namespace :superadmin do
  desc "Grant superadmin to a user by email (bin/rails superadmin:grant[user@example.com])"
  task :grant, [:email] => :environment do |_t, args|
    email = args[:email].to_s.strip.downcase
    abort "Usage: bin/rails superadmin:grant[user@example.com]" if email.blank?

    user = User.find_by!(email_address: email)
    user.update!(superadmin: true)
    puts "Granted superadmin to #{user.email_address}"
  end

  desc "Revoke superadmin from a user by email (bin/rails superadmin:revoke[user@example.com])"
  task :revoke, [:email] => :environment do |_t, args|
    email = args[:email].to_s.strip.downcase
    abort "Usage: bin/rails superadmin:revoke[user@example.com]" if email.blank?

    user = User.find_by!(email_address: email)
    user.update!(superadmin: false)
    puts "Revoked superadmin from #{user.email_address}"
  end
end
