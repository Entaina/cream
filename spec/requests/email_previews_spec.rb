require "rails_helper"

RSpec.describe "Email previews", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before { sign_in_as(member) }

  describe "POST /email_templates/preview" do
    it "renders a draft template preview" do
      layout = workspace.email_layouts.create!(name: "Shell", body: "<html><body>{{ content }}</body></html>")

      post preview_email_templates_path, params: {
        subject: "Hi {first_name}",
        body: "<p>Hello {name}</p>",
        email_layout_id: layout.id,
        preview_tokens: {first_name: "Pat", name: "Pat Smith"}
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hi Pat")
      expect(response.body).to include("Pat Smith")
      expect(response.body).to include("<iframe")
    end

    it "ignores preview token keys that are not declared in the draft content" do
      post preview_email_templates_path, params: {
        subject: "Hi {first_name}",
        body: "<p>Hello {first_name}</p>",
        preview_tokens: {first_name: "Pat", admin: "true"}
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hi Pat")
      expect(response.body).not_to include("true")
    end
  end

  describe "POST /email_layouts/preview" do
    it "renders a draft layout preview" do
      post preview_email_layouts_path, params: {
        body: "<html><body><header>Logo</header>{{ content }}</body></html>",
        sample_content: "<p>Hola {first_name}</p>",
        preview_tokens: {first_name: "Lee"}
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Logo")
      expect(response.body).to include("Hola Lee")
    end
  end

  describe "POST /record_emails/preview" do
    it "renders a compose preview for a record" do
      person = create_person!(workspace, company: companies(:acme), first_name: "Sam", last_name: "Rivera")

      post preview_record_emails_path, params: {
        record_type: "Person",
        record_id: person.id,
        subject: "Hi {first_name}",
        body: "<p>Hello {name} at {company}</p>",
        preview_tokens: {}
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hi Sam")
      expect(response.body).to include(person.display_name)
      expect(response.body).to include(companies(:acme).name)
    end
  end
end
