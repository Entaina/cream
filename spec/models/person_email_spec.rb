require "rails_helper"

RSpec.describe PersonEmail, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  it "normalizes address to lowercase" do
    company = create_company!(workspace)
    person = create_person!(workspace, company: company)

    record = person.person_emails.create!(workspace: workspace, address: "  Ana@Example.COM  ", primary: true)

    expect(record.address).to eq("ana@example.com")
    expect(person.reload.email).to eq("ana@example.com")
  end

  it "allows only one primary email per person" do
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "first@example.com")
    person.add_email!("second@example.com", primary: true)

    expect(person.person_emails.where(primary: true).count).to eq(1)
    expect(person.email).to eq("second@example.com")
  end
end
