require "rails_helper"

RSpec.describe EmailAddressParser do
  describe ".parse" do
    it "parses display name and email with trailing comma" do
      parsed = described_class.parse("Sol Fernandez <solranada@gmail.com> ,")

      expect(parsed.email).to eq("solranada@gmail.com")
      expect(parsed.first_name).to eq("Sol")
      expect(parsed.last_name).to eq("Fernandez")
      expect(parsed.name).to eq("Sol Fernandez")
    end

    it "parses quoted display names" do
      parsed = described_class.parse('"Ana García" <ana@example.com>')

      expect(parsed.email).to eq("ana@example.com")
      expect(parsed.first_name).to eq("Ana")
      expect(parsed.last_name).to eq("García")
    end

    it "returns plain email without names" do
      parsed = described_class.parse("plain@example.com")

      expect(parsed.email).to eq("plain@example.com")
      expect(parsed.first_name).to be_nil
      expect(parsed.last_name).to be_nil
    end

    it "returns nil for invalid input" do
      expect(described_class.parse("not-an-email")).to be_nil
    end
  end

  describe ".extract_all" do
    it "extracts multiple addresses from a header line" do
      emails = described_class.extract_all('Ana <ana@example.com>, Bob <bob@example.com>')

      expect(emails).to eq(%w[ana@example.com bob@example.com])
    end
  end
end
