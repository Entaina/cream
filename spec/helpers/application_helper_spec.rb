require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#money" do
    it "omits cents for whole euros" do
      expect(helper.money(1_200)).to eq("1.200 €")
    end

    it "shows cents when the amount is not a whole number" do
      expect(helper.money(590.50)).to eq("590,50 €")
    end

    it "uses English grouping when the locale is English" do
      I18n.with_locale(:en) do
        expect(helper.money(1_200)).to eq("€1,200")
        expect(helper.money(590.50)).to eq("€590.50")
      end
    end
  end
end
