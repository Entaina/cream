namespace :oauth do
  desc "Create a public OAuth client with the api scope (e.g. the Gmail add-on)"
  task :create_api_client, [:name, :redirect_uri] => :environment do |_task, args|
    abort "Usage: bin/rails \"oauth:create_api_client[Client name,https://example.com/callback]\"" if args[:name].blank? || args[:redirect_uri].blank?

    application = Doorkeeper::Application.new(
      name: args[:name],
      redirect_uri: args[:redirect_uri],
      confidential: false,
      scopes: "api"
    )
    abort application.errors.full_messages.to_sentence unless application.save

    puts "client_id: #{application.uid}"
  end
end
