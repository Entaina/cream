require "rails_helper"

RSpec.describe EmailTemplate, type: :model do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme)) }

  describe ".quill_unsupported_tags" do
    it "returns empty for quill-friendly html" do
      expect(described_class.quill_unsupported_tags("<p><strong>Hi</strong></p>")).to eq([])
    end

    it "flags table img and document tags" do
      tags = described_class.quill_unsupported_tags('<table><tr><td><img src="x"></td></tr></table><html><body></body></html>')
      expect(tags).to include("table", "tr", "td", "img", "html", "body")
    end
  end

  describe "#effective_body_editor" do
    it "returns quill when body is compatible" do
      template = described_class.new(body_editor: "quill", body: "<p>Hi</p>")
      expect(template.effective_body_editor).to eq("quill")
    end

    it "returns html when stored quill body has unsupported tags" do
      template = described_class.new(body_editor: "quill", body: "<table><tr><td>Hi</td></tr></table>")
      expect(template.effective_body_editor).to eq("html")
    end
  end

  describe "#picker_body_editor" do
    it "uses html when the template has a layout" do
      layout = workspace.email_layouts.create!(
        name: "Shell",
        body: "<html><body>{{ content }}</body></html>"
      )
      template = workspace.email_templates.create!(
        user: user, name: "Wrapped", subject: "Hi", body: "<p>Hello</p>", email_layout: layout
      )

      expect(template.picker_body_editor).to eq("html")
    end
  end

  describe "#render_for" do
    it "interpolates brace tokens without layout" do
      template = workspace.email_templates.create!(
        user: user,
        name: "Intro",
        subject: "Hi {first_name}",
        body: "Hello {name} from {company}"
      )

      expect(template.render_for(person)).to eq("Hello #{person.display_name} from #{person.company.name}")
    end

    it "escapes submitted token values in quill and html bodies" do
      %w[quill html].each do |editor|
        template = workspace.email_templates.create!(
          user: user, name: "Auto #{editor}", subject: "Hi", body_editor: editor, body: "<p>Hola {first_name}</p>"
        )

        rendered = template.render_for(person, extra_tokens: {"first_name" => "<img src=x onerror=alert(1)>"})

        expect(rendered).to eq("<p>Hola &lt;img src=x onerror=alert(1)&gt;</p>")
      end
    end

    it "escapes submitted token values in liquid bodies" do
      template = workspace.email_templates.create!(
        user: user, name: "Liquid", subject: "Hi", body_editor: "html",
        body: "<p>Hola {{ first_name }}{% if message != blank %}: {{ message }}{% endif %}</p>"
      )

      rendered = template.render_for(person, extra_tokens: {"first_name" => "<b>Ana</b>", "message" => "<a href=\"https://evil.test\">x</a>"})

      expect(rendered).to eq("<p>Hola &lt;b&gt;Ana&lt;/b&gt;: &lt;a href=&quot;https://evil.test&quot;&gt;x&lt;/a&gt;</p>")
    end

    it "escapes submitted token values used by the layout and keeps the body markup" do
      layout = workspace.email_layouts.create!(name: "Branded", body: "<div>{{ content }}<footer>{{ first_name }} {email}</footer></div>")
      template = workspace.email_templates.create!(
        user: user, name: "Wrapped", subject: "Hi", body: "<p>Hola</p>", email_layout: layout
      )

      rendered = template.render_for(person, extra_tokens: {"first_name" => "<b>Ana</b>", "email" => "<i>x</i>"})

      expect(rendered).to eq("<div><p>Hola</p><footer>&lt;b&gt;Ana&lt;/b&gt; &lt;i&gt;x&lt;/i&gt;</footer></div>")
    end

    it "does not expand tokens smuggled into submitted values through the layout" do
      layout = workspace.email_layouts.create!(name: "Simple", body: "<div>{content}</div>")
      template = workspace.email_templates.create!(
        user: user, name: "Inner", subject: "Hi", body: "<p>Hola {first_name}</p>", email_layout: layout
      )

      rendered = template.render_for(person, extra_tokens: {"first_name" => "{message}", "message" => "<a href=\"https://evil.test\">x</a>"})

      expect(rendered).to eq("<div><p>Hola {message}</p></div>")
    end

    it "does not escape tokens when rendering without submitted values" do
      layout = workspace.email_layouts.create!(name: "Simple", body: "<div>{content}<p>{first_name}</p></div>")
      template = workspace.email_templates.create!(
        user: user, name: "Plain", subject: "Hi", body: "<p>Hello {first_name}</p>", email_layout: layout
      )
      person.update!(first_name: "Ana & Co")

      expect(template.render_for(person)).to eq("<div><p>Hello Ana & Co</p><p>Ana & Co</p></div>")
    end

    it "wraps rendered body with layout content placeholder" do
      layout = workspace.email_layouts.create!(
        name: "Branded",
        body: "<html><body><header>Logo</header>{{ content }}<footer>Bye</footer></body></html>"
      )
      template = workspace.email_templates.create!(
        user: user,
        name: "Wrapped",
        subject: "Hi",
        body: "<p>Hello {first_name}</p>",
        email_layout: layout
      )

      rendered = template.render_for(person)
      expect(rendered).to include("<header>Logo</header>")
      expect(rendered).to include("<p>Hello #{person.first_name}</p>")
      expect(rendered).to include("<footer>Bye</footer>")
    end

    it "supports brace content placeholder in layout" do
      layout = workspace.email_layouts.create!(
        name: "Simple",
        body: "<div class=\"wrap\">{content}</div>"
      )
      template = workspace.email_templates.create!(
        user: user,
        name: "Inner",
        subject: "Hi",
        body: "Hello",
        email_layout: layout
      )

      expect(template.render_for(person)).to eq('<div class="wrap">Hello</div>')
    end
  end

  describe "#render_custom_for" do
    it "wraps variant body with template layout" do
      layout = workspace.email_layouts.create!(
        name: "Shell",
        body: "<html><body>{{ content }}</body></html>"
      )
      template = workspace.email_templates.create!(
        user: user,
        name: "Base",
        subject: "Base subject",
        body: "<p>ignored when variant body present</p>",
        email_layout: layout
      )

      subject, body = template.render_custom_for(person, subject: "Variant {first_name}", body: "<p>Variant body</p>")
      expect(subject).to eq("Variant #{person.first_name}")
      expect(body).to include("<p>Variant body</p>")
      expect(body).to include("<html>")
    end
  end

  describe "#picker_body" do
    it "returns raw body without layout" do
      template = workspace.email_templates.create!(user: user, name: "Plain", subject: "Hi", body: "Hello")
      expect(template.picker_body).to eq("Hello")
    end

    it "embeds template body in layout for picker" do
      layout = workspace.email_layouts.create!(name: "Shell", body: "<html><body>{{ content }}</body></html>")
      template = workspace.email_templates.create!(
        user: user,
        name: "Wrapped",
        subject: "Hi",
        body: "Hello {first_name}",
        email_layout: layout
      )

      expect(template.picker_body).to include("<html>")
      expect(template.picker_body).to include("Hello {first_name}")
    end
  end
end
