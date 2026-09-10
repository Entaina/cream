require "rails_helper"

RSpec.describe "MQL pool", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    sign_in_as(member)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  it "lists eligible MQLs" do
    person = create_person!(workspace, email: "pool@example.com")
    type = workspace.subscription_types.find_by!(slug: "general")
    Marketing::ConsentService.subscribe!(person: person, subscription_type: type, source: "spec", legal_basis: "consent")

    get mqls_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(person.display_name)
    expect(response.body).to include(type.name)
    expect(response.body).to include("Suscrito")
  end

  it "redirects when feature is disabled" do
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(false)

    get mqls_path

    expect(response).to redirect_to(root_path)
  end

  it "paginates without error when there are more than one page of MQLs" do
    type = workspace.subscription_types.find_by!(slug: "general")
    51.times do |i|
      person = create_person!(workspace, email: "pool#{i}@example.com")
      Marketing::ConsentService.subscribe!(person: person, subscription_type: type, source: "spec", legal_basis: "consent")
    end

    get mqls_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Siguiente")
  end
end
