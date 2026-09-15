require "rails_helper"

RSpec.describe LeadFormTemplates::FieldRenderer do
  describe ".parse_choice_pairs" do
    it "parses label|value pairs separated by semicolons" do
      pairs = described_class.parse_choice_pairs("Curso|curso; Entrenamiento|entrenamiento")

      expect(pairs).to eq([["Curso", "curso"], ["Entrenamiento", "entrenamiento"]])
    end

    it "uses the same string for label and value when no pipe is present" do
      pairs = described_class.parse_choice_pairs("+34; +351")

      expect(pairs).to eq([["+34", "+34"], ["+351", "+351"]])
    end

    it "returns an empty array for blank input" do
      expect(described_class.parse_choice_pairs(nil)).to eq([])
      expect(described_class.parse_choice_pairs("")).to eq([])
    end
  end

  describe "value repopulation on re-render" do
    let(:params) do
      {
        "lead" => {
          "first_name" => "Ana",
          "message" => "Hola <mundo>",
          "newsletter_opt_in" => "1",
          "phone" => "600111222",
          "phone_prefix" => "+351"
        }
      }
    end
    let(:renderer) { described_class.new(view_context: nil, params: params) }
    let(:empty_renderer) { described_class.new(view_context: nil, params: {}) }

    it "keeps the submitted value in text inputs" do
      html = renderer.render(type: "text", name: :first_name, label: "Nombre")

      expect(html).to include('value="Ana"')
    end

    it "keeps the submitted text in textareas, escaped" do
      html = renderer.render(type: "textarea", name: :message, label: "Mensaje")

      expect(html).to include(">Hola &lt;mundo&gt;</textarea>")
    end

    it "checks a checkbox that was submitted as checked" do
      html = renderer.render(type: "checkbox", name: :newsletter_opt_in, label: "Newsletter")

      expect(html).to include('checked="checked"')
    end

    it "does not check a checkbox that was not submitted" do
      html = empty_renderer.render(type: "checkbox", name: :newsletter_opt_in, label: "Newsletter")

      expect(html).not_to include('checked="checked"')
    end

    it "does not check a checkbox with a blank value on a first render" do
      html = empty_renderer.render(type: "checkbox", name: :newsletter_opt_in, label: "Newsletter", value: "")

      expect(html).not_to include('checked="checked"')
    end

    it "keeps the submitted phone and prefix" do
      html = renderer.phone_with_prefix(prefixes: "+34; +351")

      expect(html).to include('value="600111222"')
      expect(html).to include('<option value="+351" selected="selected">')
    end

    it "renders no value attribute when nothing was submitted" do
      html = empty_renderer.render(type: "text", name: :first_name, label: "Nombre")

      expect(html).not_to include("value=")
    end
  end
end
