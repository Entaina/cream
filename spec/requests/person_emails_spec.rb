require "rails_helper"

RSpec.describe "Person emails", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(WebhookDeliveryJob).to receive(:perform_later)
    allow(AutomationJob).to receive(:perform_later)
  end

  describe "PATCH /people/:id (emails via edit form)" do
    it "adds an email without removing the existing one" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "primary@example.com")
      primary_record = person.person_emails.first

      expect {
        patch person_path(person), params: {
          person: {
            person_emails_attributes: {
              "0" => {id: primary_record.id, address: "primary@example.com", primary: "1"},
              "1" => {address: "secondary@example.com", primary: "0"}
            }
          }
        }
      }.to change { person.person_emails.count }.by(1)

      expect(response).to redirect_to(person)
      person.reload
      expect(person.person_emails.pluck(:address)).to contain_exactly("primary@example.com", "secondary@example.com")
      expect(person.email).to eq("primary@example.com")
    end

    it "marks an email as primary" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "primary@example.com")
      secondary = person.add_email!("secondary@example.com")
      primary_record = person.person_emails.find_by(address: "primary@example.com")

      patch person_path(person), params: {
        person: {
          person_emails_attributes: {
            "0" => {id: primary_record.id, address: "primary@example.com", primary: "0"},
            "1" => {id: secondary.id, address: "secondary@example.com", primary: "1"}
          }
        }
      }

      expect(response).to redirect_to(person)
      person.reload
      expect(person.email).to eq("secondary@example.com")
      expect(secondary.reload).to be_primary
      expect(primary_record.reload).not_to be_primary
    end

    it "removes one email without affecting the others" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "primary@example.com")
      secondary = person.add_email!("secondary@example.com")
      primary_record = person.person_emails.find_by(address: "primary@example.com")

      expect {
        patch person_path(person), params: {
          person: {
            person_emails_attributes: {
              "0" => {id: primary_record.id, address: "primary@example.com", primary: "1"},
              "1" => {id: secondary.id, address: "secondary@example.com", primary: "0", _destroy: "1"}
            }
          }
        }
      }.to change { person.person_emails.count }.by(-1)

      expect(response).to redirect_to(person)
      person.reload
      expect(person.person_emails.pluck(:address)).to eq(["primary@example.com"])
    end
  end

  describe "GET /people (search)" do
    it "finds a person by any of their emails" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "primary@example.com", first_name: "MultiEmail")
      person.add_email!("alias@example.com")

      get people_path(q: "alias@example.com")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.display_name)
    end
  end
end
