require "rails_helper"

RSpec.describe FormulaEvaluator do
  fixtures :users, :workspaces, :memberships

  it "evaluates arithmetic expressions with record tokens" do
    deal = create_deal!(workspaces(:one))
    deal.update!(value: 1000, probability: 50)

    result = described_class.evaluate("{value} * {probability} / 100", record: deal)
    expect(result).to eq(500.0)
  end
end
