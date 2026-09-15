require "rails_helper"

RSpec.describe "Email templates", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before { sign_in_as(member) }

  describe "CRUD" do
    it "returns template JSON for composer copy-on-select" do
      template = create_email_template!(workspace, user: member, name: "Base", subject: "Hi", body: "<p>Body</p>")

      get email_template_path(template, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "subject" => "Hi",
        "body" => a_string_including("Body"),
        "body_editor" => "quill"
      )
    end

    it "shows preview panel on new template form" do
      get new_email_template_path

      expect(response.body).to include('data-controller="email-preview"')
      expect(response.body).to include("Vista previa")
      expect(response.body).to include("{first_name}")
    end

    it "creates a template" do
      expect {
        post email_templates_path, params: {
          email_template: {name: "Intro", subject: "Hi {first_name}", body: "Hello {name}", shared: "1"}
        }
      }.to change(EmailTemplate, :count).by(1)

      expect(response).to redirect_to(email_templates_path)
    end

    it "creates a template with HTML body" do
      post email_templates_path, params: {
        email_template: {
          name: "Styled",
          subject: "Hi",
          body: "<p><strong>Hello</strong> {first_name}</p>"
        }
      }

      template = EmailTemplate.order(:id).last
      expect(template.body).to include("<strong>Hello</strong>")
    end

    it "creates a template in html mode with tables and layout" do
      layout = workspace.email_layouts.create!(name: "Shell", body: "<html><body>{{ content }}</body></html>")

      post email_templates_path, params: {
        email_template: {
          name: "Table mail",
          subject: "Hi",
          body: "<table><tr><td>Hello</td></tr></table>",
          body_editor: "html",
          email_layout_id: layout.id
        }
      }

      template = EmailTemplate.order(:id).last
      expect(template.body_editor).to eq("html")
      expect(template.body).to include("<table>")
      expect(template.email_layout).to eq(layout)
    end

    it "creates a template with attachments" do
      file = fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")

      post email_templates_path, params: {
        email_template: {name: "With file", subject: "Hi", body: "Hello", attachments: [file]}
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
        email_template: {name: "Intro", subject: "Hi", body: "Hello"},
        purge_attachment_ids: [remove_id]
      }

      filenames = template.reload.attachments.map { |f| f.filename.to_s }
      expect(filenames).to eq(["keep.txt"])
    end

    it "keeps existing attachments when updating without new files" do
      template = workspace.email_templates.create!(user: member, name: "Intro", subject: "Hi", body: "Hello")
      template.attachments.attach(io: StringIO.new("keep"), filename: "keep.txt", content_type: "text/plain")

      # Browsers submit an empty string for an untouched multiple file input.
      patch email_template_path(template), params: {
        email_template: {name: "Intro updated", subject: "Hi", body: "Hello", attachments: [""]}
      }

      expect(response).to redirect_to(email_templates_path)
      template.reload
      expect(template.name).to eq("Intro updated")
      expect(template.attachments.map { |f| f.filename.to_s }).to eq(["keep.txt"])
    end

    it "appends new attachments on update without replacing existing ones" do
      template = workspace.email_templates.create!(user: member, name: "Intro", subject: "Hi", body: "Hello")
      template.attachments.attach(io: StringIO.new("keep"), filename: "keep.txt", content_type: "text/plain")
      new_file = fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")

      patch email_template_path(template), params: {
        email_template: {name: "Intro", subject: "Hi", body: "Hello", attachments: [new_file]}
      }

      filenames = template.reload.attachments.map { |f| f.filename.to_s }
      expect(filenames).to contain_exactly("keep.txt", "sample.txt")
    end
  end

  describe "composer integration" do
    it "renders the template picker with subject/body data on a record page" do
      workspace.email_templates.create!(user: member, name: "Intro", subject: "Hi {first_name}", body: "Hello {name}")
      person = create_person!(workspace, company: companies(:acme))

      get person_path(person)

      expect(response.body).to include('data-controller="template-picker"')
      expect(response.body).to include('data-controller="rich-text-editor"')
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

    it "includes wrapped picker body when template has layout" do
      layout = workspace.email_layouts.create!(name: "Shell", body: "<html><body>{{ content }}</body></html>")
      workspace.email_templates.create!(
        user: member,
        name: "Wrapped",
        subject: "Hi {first_name}",
        body: "Hello {name}",
        email_layout: layout
      )
      person = create_person!(workspace, company: companies(:acme))

      get person_path(person)

      expect(response.body).to include("Hello {name}")
      expect(response.body).to include("data-body=")
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
