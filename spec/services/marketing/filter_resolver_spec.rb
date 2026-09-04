require "rails_helper"

RSpec.describe Marketing::FilterResolver do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  it "filters people by visited url" do
    person = create_person!(workspace, email: "visitor@example.com")
    workspace.page_views.create!(
      person: person,
      anonymous_id: "abc",
      url: "https://example.com/pricing",
      occurred_at: Time.current
    )

    resolver = described_class.new(
      workspace: workspace,
      record_type: "Person",
      filters: { "visited_url" => "pricing" }
    )

    expect(resolver.resolve(workspace.people)).to contain_exactly(person)
  end
end
