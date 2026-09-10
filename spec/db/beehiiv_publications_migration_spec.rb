require "rails_helper"

RSpec.describe "CreateBeehiivPublications migration backfill" do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  it "preserves legacy webhook_token and publication_id when backfilling" do
    legacy_token = "legacy-backfill-token"
    legacy_publication_id = "pub_11111111-1111-1111-1111-111111111111"
    legacy_secret = "whsec_legacysecret"

    SubscriptionType.ensure_defaults!(workspace)
    newsletter_type = workspace.subscription_types.find_by!(slug: "newsletter")

    connection = workspace.create_beehiiv_connection!(user: user, api_key: "legacy-key")
    publication = connection.beehiiv_publications.create!(
      subscription_type: newsletter_type,
      publication_id: legacy_publication_id,
      webhook_token: legacy_token,
      webhook_signing_secret: legacy_secret
    )

    expect(publication.publication_id).to eq(legacy_publication_id)
    expect(publication.webhook_token).to eq(legacy_token)
    expect(publication.webhook_signing_secret).to eq(legacy_secret)
    expect(publication.webhook_url).to include(legacy_token)
  end
end
