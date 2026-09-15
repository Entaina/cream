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

    it "keeps table and img tags in fragments" do
      html = helper.email_body_html('<table><tr><td><img src="https://example.com/a.png" alt="logo"></td></tr></table>')

      expect(html).to include("<table>")
      expect(html).to include("<img")
    end

    it "preserves full html documents with tables" do
      document = <<~HTML
        <!DOCTYPE html>
        <html><body><table><tr><td>Hi</td></tr></table></body></html>
      HTML
      html = helper.email_body_html(document)

      expect(html).to include("<html>")
      expect(html).to include("<table>")
    end

    it "returns an empty string for blank input" do
      expect(helper.email_body_html("")).to eq("")
      expect(helper.email_body_html(nil)).to eq("")
    end
  end

  describe "#full_html_document?" do
    it "detects doctype and html tags" do
      expect(helper.full_html_document?("<!DOCTYPE html><html></html>")).to be(true)
      expect(helper.full_html_document?("<p>Hi</p>")).to be(false)
    end
  end

  describe "#insert_open_tracking_pixel" do
    it "inserts before closing body tag" do
      html = helper.insert_open_tracking_pixel("<html><body>Hi</body></html>", "https://example.com/open")
      expect(html).to include('src="https://example.com/open"')
      expect(html).to match(/<img[^>]+><\/body>/)
    end
  end

  describe "#email_body_preview" do
    it "strips tags before truncating" do
      preview = helper.email_body_preview("<p><strong>Hello</strong> world</p>", length: 20)

      expect(preview).to eq("Hello world")
    end
  end
end
