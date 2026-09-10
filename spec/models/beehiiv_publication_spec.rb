require "rails_helper"

RSpec.describe BeehiivPublication do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  before do
    SubscriptionType.ensure_defaults!(workspace)
  end

  it "preserves a provided webhook_token for production continuity" do
    legacy_token = "legacy-production-token-abc123"
    publication = create_beehiiv_publication!(workspace, webhook_token: legacy_token)

    expect(publication.reload.webhook_token).to eq(legacy_token)
    expect(publication.webhook_url).to include(legacy_token)
  end

  it "assigns a webhook_token when none is provided" do
    publication = create_beehiiv_publication!(workspace)

    expect(publication.webhook_token).to be_present
  end

  it "requires subscription_type from the same workspace" do
    other_workspace = workspaces(:two)
    SubscriptionType.ensure_defaults!(other_workspace)
    connection = workspace.create_beehiiv_connection!(user: users(:one), api_key: "key")
    other_type = other_workspace.subscription_types.find_by!(slug: "newsletter")

    publication = connection.beehiiv_publications.build(
      subscription_type: other_type,
      publication_id: "pub_00000000-0000-0000-0000-000000000001"
    )

    expect(publication).not_to be_valid
    expect(publication.errors[:subscription_type]).to be_present
  end
end
