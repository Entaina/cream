require "rails_helper"

RSpec.describe EmailTemplatePreview do
  fixtures :users, :workspaces, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme)) }

  describe ".extract_tokens" do
    it "finds brace and liquid tokens excluding content" do
      tokens = described_class.extract_tokens("Hi {first_name}", "<p>{{ name }} and {event_name}</p>", "{{ content }}")
      expect(tokens).to include("first_name", "name", "event_name")
      expect(tokens).not_to include("content")
    end
  end

  describe ".render_template" do
    it "uses sample defaults when preview tokens are blank" do
      layout = workspace.email_layouts.create!(name: "Shell", body: "<html><body>{{ content }}</body></html>")
      subject, body = described_class.render_template(
        subject: "Hi {first_name}",
        body: "<p>Hello {name}</p>",
        layout: layout,
        extra_tokens: {}
      )

      expect(subject).to eq("Hi María")
      expect(body).to include("María García")
      expect(body).to include("<html>")
    end

    it "prefers provided preview tokens over defaults" do
      subject, body = described_class.render_template(
        subject: "Hi {first_name}",
        body: "Hello {name}",
        layout: nil,
        extra_tokens: { "first_name" => "Alex", "name" => "Alex Example" }
      )

      expect(subject).to eq("Hi Alex")
      expect(body).to eq("Hello Alex Example")
    end
  end

  describe ".render_layout" do
    it "wraps sample content with layout tokens resolved" do
      _subject, body = described_class.render_layout(
        body: "<div class=\"wrap\">{{ content }} — {company}</div>",
        sample_content: "<p>Hola {first_name}</p>",
        extra_tokens: { "company" => "Example Inc." }
      )

      expect(body).to include("Hola María")
      expect(body).to include("Example Inc.")
    end
  end

  describe ".render_email" do
    it "renders ad-hoc compose content" do
      subject, body = described_class.render_email(
        subject: "Follow up {first_name}",
        body: "<p>Hi {name} from {company}</p>",
        extra_tokens: { "first_name" => "Jo", "name" => "Jo Lee", "company" => "Beta" }
      )

      expect(subject).to eq("Follow up Jo")
      expect(body).to include("Jo Lee")
      expect(body).to include("Beta")
    end
  end
end
