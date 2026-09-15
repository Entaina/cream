require "rails_helper"

RSpec.describe LeadSubmissionsHelper, type: :helper do
  describe "#sanitize_accepted_policy_html" do
    it "keeps the policy wording and semantic markup" do
      html = helper.sanitize_accepted_policy_html(
        '<h1>Política de privacidad</h1><p>Tratamos tus <strong>datos</strong>.</p><a href="https://example.test/privacy">Más info</a>'
      )

      expect(html).to include("<h1>Política de privacidad</h1>")
      expect(html).to include("<strong>datos</strong>")
      expect(html).to include('href="https://example.test/privacy"')
    end

    it "drops public-page classes, inline colors and stylesheet text" do
      html = helper.sanitize_accepted_policy_html(<<~HTML)
        <style>.policy-leak-marker { color: #111; background: #fff; }</style>
        <h1 class="text-2xl text-white bg-white" style="color:#111;background:#fff">Política de prueba</h1>
        <p class="text-gray-900">Cuerpo</p>
      HTML

      expect(html).to include("Política de prueba")
      expect(html).to include("Cuerpo")
      expect(html).not_to include("policy-leak-marker")
      expect(html).not_to include("text-white")
      expect(html).not_to include("bg-white")
      expect(html).not_to include("text-gray-900")
      expect(html).not_to include("color:#111")
      expect(html).not_to include("<style")
    end

    it "returns an empty string for blank input" do
      expect(helper.sanitize_accepted_policy_html("")).to eq("")
      expect(helper.sanitize_accepted_policy_html(nil)).to eq("")
    end
  end
end
