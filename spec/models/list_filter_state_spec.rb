require "rails_helper"

RSpec.describe ListFilterState, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:session) { user.sessions.create! }
  let(:key) { "people#index" }

  it "read/write roundtrip" do
    ListFilterState.write(
      session: session,
      workspace: workspace,
      key: key,
      params: { "q" => "ana", "sort" => "first_name" }
    )

    stored = ListFilterState.read(session: session, workspace: workspace, key: key)
    expect(stored).to include("q" => "ana", "sort" => "first_name")
  end

  it "upserts the same key" do
    ListFilterState.write(session: session, workspace: workspace, key: key, params: { "q" => "a" })
    expect(ListFilterState.where(session: session).count).to eq(1)

    ListFilterState.write(session: session, workspace: workspace, key: key, params: { "q" => "b" })
    expect(ListFilterState.where(session: session).count).to eq(1)
    expect(ListFilterState.read(session: session, workspace: workspace, key: key)).to include("q" => "b")
  end

  it "delete removes stored filters" do
    ListFilterState.write(session: session, workspace: workspace, key: key, params: { "q" => "x" })
    ListFilterState.delete(session: session, workspace: workspace, key: key)
    expect(ListFilterState.read(session: session, workspace: workspace, key: key)).to be_nil
  end

  it "read returns nil for a different workspace" do
    other_workspace = workspaces(:two)
    ListFilterState.write(session: session, workspace: workspace, key: key, params: { "q" => "x" })

    expect(ListFilterState.read(session: session, workspace: other_workspace, key: key)).to be_nil
  end

  it "deletes with session" do
    ListFilterState.write(session: session, workspace: workspace, key: key, params: { "q" => "x" })
    expect { session.destroy! }.to change(ListFilterState, :count).by(-1)
  end

  it "enforces unique index per session, workspace and key" do
    ListFilterState.create!(session: session, workspace: workspace, key: key, params: {})
    expect {
      ListFilterState.create!(session: session, workspace: workspace, key: key, params: { "q" => "dup" })
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
