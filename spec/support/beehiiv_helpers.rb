module BeehiivHelpers
  def create_beehiiv_publication!(workspace, user: users(:one), subscription_slug: "newsletter", **attrs)
    SubscriptionType.ensure_defaults!(workspace)
    connection = workspace.beehiiv_connection || workspace.create_beehiiv_connection!(
      user: user,
      api_key: attrs.delete(:api_key) || "beehiiv-api-key"
    )
    subscription_type = workspace.subscription_types.find_by!(slug: subscription_slug)
    defaults = {
      subscription_type: subscription_type,
      publication_id: "pub_00000000-0000-0000-0000-000000000000"
    }
    connection.beehiiv_publications.create!(defaults.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include BeehiivHelpers
end
