require "rails_helper"

RSpec.describe "Email templates", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before { sign_in_as(member) }

  describe "CRUD" do
    it "creates a template" do
      expect {
        post email_templates_path, params: {
          email_template: { name: "Intro", subject: "Hi {first_name}", body: "Hello {name}", shared: "1" }
        }
      }.to change(EmailTemplate, :count).by(1)

      expect(response).to redirect_to(email_templates_path)
    end

    it "creates a template with attachments" do
      file = fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")

      post email_templates_path, params: {
        email_template: { name: "With file", subject: "Hi", body: "Hello", attachments: [ file ] }
      }

      template = EmailTemplate.order(:id).last
      expect(template.attachments).to be_attached
      expect(template.attachments.first.filename.to_s).to eq("sample.txt")
    end

    it "purges selected attachments on update" do
      template = workspace.email_templates.create!(user: member, name: "Intro", subject: "Hi", body: "Hello")
      template.attachments.attach(io: StringIO.new("keep"), filename: "keep.txt", content_type: "text/plain")
      template.attachments.attach(io: StringIO.new("remove"), filename: "remove.txt", content_type: "text/plain")
      remove_id = template.attachments.find { |f| f.filename.to_s == "remove.txt" }.id

      patch email_template_path(template), params: {
        email_template: { name: "Intro", subject: "Hi", body: "Hello" },
        purge_attachment_ids: [ remove_id ]
      }

      filenames = template.reload.attachments.map { |f| f.filename.to_s }
      expect(filenames).to eq([ "keep.txt" ])
    end
  end

  describe "composer integration" do
    it "renders the template picker with subject/body data on a record page" do
      workspace.email_templates.create!(user: member, name: "Intro", subject: "Hi {first_name}", body: "Hello {name}")
      person = create_person!(workspace, company: companies(:acme))

      get person_path(person)

      expect(response.body).to include('data-controller="template-picker"')
      expect(response.body).to include("Insertar plantilla")
      expect(response.body).to include("Hi {first_name}")
    end

    it "shows the picker with empty state when no templates exist" do
      person = create_person!(workspace, company: companies(:acme))

      get person_path(person)

      expect(response.body).to include('data-controller="template-picker"')
      expect(response.body).to include("No hay plantillas disponibles")
      expect(response.body).to include("Crear plantillas")
    end

    it "renders attachment metadata on template options for deal compose" do
      template = workspace.email_templates.create!(user: member, name: "With files", subject: "Hi", body: "Hello")
      template.attachments.attach(
        io: StringIO.new("file content"),
        filename: "brochure.pdf",
        content_type: "application/pdf"
      )
      deal = create_deal!(workspace, company: companies(:acme))

      get deal_path(deal)

      expect(response.body).to include('data-attachments="[{&quot;id&quot;:')
      expect(response.body).to include('data-template-picker-target="attachmentList"')
    end
  end
end
