require "rails_helper"

RSpec.describe Marketing::ConditionEvaluator do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:person) do
    create_person!(workspace, company: companies(:acme), email: "pat@acme.com", lead_score: 42)
  end

  def evaluate(condition, metadata: {})
    described_class.new(condition).met_for_person?(person, metadata: metadata)
  end

  it "evaluates eq and neq on person fields" do
    expect(evaluate({"field" => "person.email", "operator" => "eq", "compare_value" => "pat@acme.com"})).to be true
    expect(evaluate({"field" => "person.email", "operator" => "neq", "compare_value" => "other@acme.com"})).to be true
  end

  it "evaluates contains case-insensitively" do
    expect(evaluate({"field" => "email", "operator" => "contains", "compare_value" => "ACME"})).to be true
  end

  it "evaluates numeric comparisons on lead_score" do
    expect(evaluate({"field" => "lead_score", "operator" => "gt", "compare_value" => 40})).to be true
    expect(evaluate({"field" => "lead_score", "operator" => "gte", "compare_value" => 42})).to be true
    expect(evaluate({"field" => "lead_score", "operator" => "lt", "compare_value" => 50})).to be true
    expect(evaluate({"field" => "lead_score", "operator" => "lte", "compare_value" => 42})).to be true
  end

  it "evaluates blank and present" do
    expect(evaluate({"field" => "phone", "operator" => "blank", "compare_value" => nil})).to be true
    expect(evaluate({"field" => "email", "operator" => "present", "compare_value" => nil})).to be true
  end

  it "reads metadata fields" do
    expect(evaluate({"field" => "metadata.campaign", "operator" => "eq", "compare_value" => "spring"},
      metadata: {"campaign" => "spring"})).to be true
  end

  it "returns false for unknown operators" do
    expect(evaluate({"field" => "email", "operator" => "magic", "compare_value" => "x"})).to be false
  end
end
