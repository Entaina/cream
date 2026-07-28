require "rails_helper"

RSpec.describe DealAccess, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:owner) { users(:one) }
  let(:collaborator) { users(:two) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, owner: owner) }

  it "belongs to a deal and user" do
    access = deal.deal_accesses.create!(user: collaborator)

    expect(access.deal).to eq(deal)
    expect(access.user).to eq(collaborator)
    expect(deal.collaborators).to include(collaborator)
  end

  it "requires unique user per deal" do
    deal.deal_accesses.create!(user: collaborator)

    duplicate = deal.deal_accesses.build(user: collaborator)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end

  it "rejects users outside the deal workspace" do
    outsider = users(:outsider)
    access = deal.deal_accesses.build(user: outsider)

    expect(access).not_to be_valid
    expect(access.errors[:user]).to include("must belong to the deal workspace")
  end
end
