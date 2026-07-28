require "rails_helper"

RSpec.describe CompanyDuplicateGroups do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "groups companies with similar normalized names" do
    mapfre = create_company!(workspace, name: "Mapfre")
    mapfre_spain = create_company!(workspace, name: "Mapfre España")

    groups = described_class.call(workspace)

    matching = groups.find { |group| group.companies.include?(mapfre) }
    expect(matching.reason).to include("Similar name")
    expect(matching.companies).to eq([ mapfre, mapfre_spain ])
  end

  it "groups companies with the same normalized domain" do
    first = workspace.companies.create!(name: "Acme East", domain: "www.acme.com")
    second = workspace.companies.create!(name: "Acme West", domain: "acme.com")

    groups = described_class.call(workspace)

    matching = groups.find { |group| group.companies.include?(first) }
    expect(matching.reason).to include("Same domain")
    expect(matching.companies).to eq([ first, second ])
  end

  it "does not group unrelated companies" do
    workspace.companies.create!(name: "WidgetCo")
    workspace.companies.create!(name: "WidgetCo East")

    groups = described_class.call(workspace).select do |group|
      group.companies.any? { |company| company.name.start_with?("WidgetCo") }
    end

    expect(groups).to be_empty
  end

  it "builds transitive groups when companies match through a third company" do
    alpha = workspace.companies.create!(name: "Mapfre", domain: "mapfre.com")
    beta = create_company!(workspace, name: "Mapfre España")
    gamma = workspace.companies.create!(name: "Mapfre SA", domain: "mapfre.com")

    groups = described_class.call(workspace)

    expect(groups.size).to eq(1)
    expect(groups.first.companies).to eq([ alpha, beta, gamma ])
  end

  it "returns multiple groups ordered by primary company name" do
    beta = create_company!(workspace, name: "Beta")
    beta_spain = create_company!(workspace, name: "Beta España")
    alpha = create_company!(workspace, name: "Alpha")
    alpha_spain = create_company!(workspace, name: "Alpha España")

    groups = described_class.call(workspace)

    expect(groups.size).to eq(2)
    expect(groups.map { |group| group.companies.first.name }).to eq([ "Alpha", "Beta" ])
    expect(groups[0].companies).to eq([ alpha, alpha_spain ])
    expect(groups[1].companies).to eq([ beta, beta_spain ])
  end
end
