require "rails_helper"

RSpec.describe "SubscriptionTypes", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
    sign_in_as(admin)
  end

  it "creates a subscription type" do
    expect {
      post subscription_types_path, params: {
        subscription_type: {
          name: "Product updates",
          slug: "product-updates",
          consent_field_key: "product_updates_consent",
          active: true
        }
      }
    }.to change(SubscriptionType, :count).by(1)

    expect(response).to redirect_to(subscription_types_path)
  end

  it "updates a subscription type" do
    type = workspace.subscription_types.find_by!(slug: "newsletter")

    patch subscription_type_path(type), params: {subscription_type: {description: "Monthly digest"}}

    expect(response).to redirect_to(subscription_types_path)
    expect(type.reload.description).to eq("Monthly digest")
  end

  it "forbids non-admin members" do
    sign_in_as(salesperson)
    patch switch_workspace_path, params: {workspace_id: workspace.id}

    get subscription_types_path

    expect(response).to redirect_to(root_path)
  end
end
