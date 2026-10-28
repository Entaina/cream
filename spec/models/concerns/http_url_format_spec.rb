require "rails_helper"

RSpec.describe HttpUrlFormat do
  fixtures :workspaces, :companies

  let(:workspace) { workspaces(:one) }

  def person_with(url)
    workspace.people.new(first_name: "Pat", company: companies(:acme), linkedin_url: url)
  end

  it "accepts http and https URLs" do
    expect(person_with("https://www.linkedin.com/in/pat")).to be_valid
    expect(person_with("http://linkedin.com/in/pat")).to be_valid
  end

  it "adds https to a bare domain" do
    person = person_with("linkedin.com/in/pat")

    expect(person).to be_valid
    expect(person.linkedin_url).to eq("https://linkedin.com/in/pat")
  end

  it "allows blank values" do
    expect(person_with("")).to be_valid
    expect(person_with(nil)).to be_valid
  end

  it "rejects script and other non-web schemes" do
    ["javascript:alert(1)", "JavaScript:alert(1)", "data:text/html,<script>alert(1)</script>",
      "vbscript:msgbox(1)", "ftp://files.example.com/x"].each do |url|
      person = person_with(url)

      expect(person).not_to be_valid, url
      expect(person.errors[:linkedin_url]).to be_present
    end
  end

  it "rejects values that are not URLs" do
    expect(person_with("not a url")).not_to be_valid
    expect(person_with("https://")).not_to be_valid
  end

  it "validates both social URLs on companies" do
    company = workspace.companies.new(name: "Acme", linkedin_url: "javascript:alert(1)", twitter_url: "x.com/acme")

    expect(company).not_to be_valid
    expect(company.errors[:linkedin_url]).to be_present
    expect(company.twitter_url).to eq("https://x.com/acme")
    expect(company.errors[:twitter_url]).to be_empty
  end
end
