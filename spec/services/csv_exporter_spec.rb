require "rails_helper"

RSpec.describe CsvExporter do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  describe ".escape_formula" do
    it "prefixes text that a spreadsheet would run as a formula" do
      expect(described_class.escape_formula("=HYPERLINK(\"http://evil\")")).to eq("'=HYPERLINK(\"http://evil\")")
      expect(described_class.escape_formula("+34 600 000 000")).to eq("'+34 600 000 000")
      expect(described_class.escape_formula("-cmd")).to eq("'-cmd")
      expect(described_class.escape_formula("@SUM(A1)")).to eq("'@SUM(A1)")
    end

    it "leaves other values untouched" do
      expect(described_class.escape_formula("Ada")).to eq("Ada")
      expect(described_class.escape_formula(-500)).to eq(-500)
      expect(described_class.escape_formula(BigDecimal("1500.5"))).to eq(BigDecimal("1500.5"))
      expect(described_class.escape_formula(Date.new(2026, 1, 1))).to eq(Date.new(2026, 1, 1))
      expect(described_class.escape_formula(nil)).to be_nil
    end
  end

  it "escapes formula-like person fields and keeps empty fields empty" do
    create_person!(workspace, first_name: "=HYPERLINK(\"http://evil\",\"x\")", last_name: "Doe", phone: "+34 600 000 000")

    rows = CSV.parse(described_class.export("Person", scope: workspace.people), headers: true)
    row = rows.first

    expect(row["first_name"]).to eq("'=HYPERLINK(\"http://evil\",\"x\")")
    expect(row["phone"]).to eq("'+34 600 000 000")
    expect(row["email"]).to be_nil
  end

  it "exports deal numbers and dates unchanged" do
    create_deal!(workspace, name: "Big deal", value: 1500, probability: 40, expected_close_date: Date.new(2026, 3, 1))

    row = CSV.parse(described_class.export("Deal", scope: workspace.deals), headers: true).find { |r| r["name"] == "Big deal" }

    expect(row["value"]).to eq(BigDecimal("1500").to_s)
    expect(row["probability"]).to eq("40")
    expect(row["expected_close_date"]).to eq("2026-03-01")
  end

  it "re-imports an exported file without losing the original values" do
    create_person!(workspace, first_name: "=1+1", last_name: "Doe", email: "roundtrip@example.com", phone: "+34 600 000 000")
    csv = described_class.export("Person", scope: workspace.people.where(email: "roundtrip@example.com"))
    workspace.people.where(email: "roundtrip@example.com").destroy_all

    result = CsvImporter.import("Person", workspace: workspace, user: user, io: StringIO.new(csv))

    expect(result.errors).to be_empty
    person = workspace.people.find_by!(email: "roundtrip@example.com")
    expect(person.first_name).to eq("=1+1")
    expect(person.phone).to eq("+34 600 000 000")
  end
end
