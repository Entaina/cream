require "rails_helper"

RSpec.describe LeadForms::FreeEmailDomain do
  describe ".blocked?" do
    it "blocks known free email domains" do
      expect(described_class.blocked?("ana@gmail.com")).to be(true)
      expect(described_class.blocked?("ana@outlook.com")).to be(true)
      expect(described_class.blocked?("ana@hotmail.es")).to be(true)
    end

    it "does not block corporate-looking domains" do
      expect(described_class.blocked?("ana@entaina.com")).to be(false)
      expect(described_class.blocked?("ana@empresa.es")).to be(false)
    end

    it "is case-insensitive" do
      expect(described_class.blocked?("Ana@Gmail.COM")).to be(true)
    end

    it "returns false for blank or malformed email" do
      expect(described_class.blocked?("")).to be(false)
      expect(described_class.blocked?("not-an-email")).to be(false)
    end
  end
end
