require "rails_helper"

RSpec.describe EmailHelper, type: :helper do
  describe "#email_body_html" do
    it "formats plain text with paragraphs" do
      html = helper.email_body_html("Hello\nWorld")

      expect(html).to include("Hello")
      expect(html).to include("World")
      expect(html).to include("<p>")
    end

    it "sanitizes dangerous HTML while keeping inline styles" do
      html = helper.email_body_html('<p style="color: red;">Hi</p><script>alert(1)</script>')

      expect(html).to include('style="color:red;"')
      expect(html).not_to include("<script>")
    end

    it "returns an empty string for blank input" do
      expect(helper.email_body_html("")).to eq("")
      expect(helper.email_body_html(nil)).to eq("")
    end
  end

  describe "#email_body_preview" do
    it "strips tags before truncating" do
      preview = helper.email_body_preview('<p><strong>Hello</strong> world</p>', length: 20)

      expect(preview).to eq("Hello world")
    end
  end
end
