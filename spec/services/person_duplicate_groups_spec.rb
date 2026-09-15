require "rails_helper"

RSpec.describe PersonDuplicateGroups do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "groups people with the same normalized email within a company" do
    company = create_company!(workspace)
    first = create_person!(workspace, company: company, email: "Pat@Acme.com")
    second = create_person!(workspace, company: company, email: "pat@acme.com")

    groups = described_class.call(workspace)

    matching = groups.find { |group| group.email == "pat@acme.com" }
    expect(matching.company_label).to eq(company.name)
    expect(matching.people).to eq([first, second])
  end

  it "does not group people with blank emails" do
    company = create_company!(workspace)
    create_person!(workspace, company: company, email: "")
    create_person!(workspace, company: company, email: nil)

    expect(described_class.call(workspace)).to be_empty
  end

  it "groups the same email across different companies" do
    company_a = create_company!(workspace, name: "Alpha")
    company_b = create_company!(workspace, name: "Beta")
    first = create_person!(workspace, company: company_a, email: "shared@example.com")
    second = create_person!(workspace, company: company_b, email: "shared@example.com")

    groups = described_class.call(workspace)

    expect(groups.size).to eq(1)
    expect(groups.first.email).to eq("shared@example.com")
    expect(groups.first.company_label).to eq("Alpha, Beta")
    expect(groups.first.people).to eq([first, second])
  end

  it "returns multiple groups ordered by company label and email" do
    company_a = create_company!(workspace, name: "Alpha")
    company_b = create_company!(workspace, name: "Beta")
    create_person!(workspace, company: company_a, email: "dup@alpha.com")
    create_person!(workspace, company: company_a, email: "dup@alpha.com")
    create_person!(workspace, company: company_b, email: "dup@beta.com")
    create_person!(workspace, company: company_b, email: "dup@beta.com")

    groups = described_class.call(workspace)

    expect(groups.size).to eq(2)
    expect(groups.map(&:email)).to eq(["dup@alpha.com", "dup@beta.com"])
  end
end
