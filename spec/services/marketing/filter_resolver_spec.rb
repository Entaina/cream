require "rails_helper"

RSpec.describe Marketing::FilterResolver do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  it "filters people without open deals" do
    company = create_company!(workspace)
    person_with_deal = create_person!(workspace, email: "with-deal@example.com", company: company)
    person_without = create_person!(workspace, email: "without@example.com")
    create_deal!(workspace, company: company, contacts: [person_with_deal])

    resolver = described_class.new(
      workspace: workspace,
      record_type: "Person",
      filters: {"open_deal" => "no"}
    )

    expect(resolver.resolve(workspace.people)).to contain_exactly(person_without)
  end

  it "filters people by pending product interest" do
    person = create_person!(workspace, email: "interest@example.com")
    product = workspace.products.create!(name: "Curso", price: 10)
    Marketing::ProductInterest.create!(
      workspace: workspace,
      person: person,
      product: product,
      description: "Preguntó por curso",
      source_kind: "manual",
      occurred_at: Time.current
    )

    resolver = described_class.new(
      workspace: workspace,
      record_type: "Person",
      filters: {"interest_product_id" => product.id, "interest_status" => "pending"}
    )

    expect(resolver.resolve(workspace.people)).to contain_exactly(person)
  end

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
      filters: {"visited_url" => "pricing"}
    )

    expect(resolver.resolve(workspace.people)).to contain_exactly(person)
  end
end
