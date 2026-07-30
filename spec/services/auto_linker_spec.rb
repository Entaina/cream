require "rails_helper"

RSpec.describe AutoLinker do
  describe ".render_html" do
    it "converts a single http URL into a clickable link" do
      html = described_class.render_html("See https://example.com for details")

      expect(html).to include('href="https://example.com"')
      expect(html).to include('target="_blank"')
      expect(html).to include('rel="noopener noreferrer"')
      expect(html).to include('class="text-accent underline"')
      expect(html).to include("See ")
      expect(html).to include(" for details")
    end

    it "converts multiple URLs while preserving surrounding text" do
      html = described_class.render_html("Basecamp: https://3.basecamp.com/123 and Drive: http://drive.google.com/file/abc")

      expect(html).to include('href="https://3.basecamp.com/123"')
      expect(html).to include('href="http://drive.google.com/file/abc"')
      expect(html).to include("Basecamp:")
      expect(html).to include(" and Drive: ")
    end

    it "excludes trailing punctuation from the link" do
      html = described_class.render_html("Check https://example.com/path.")

      expect(html).to include('href="https://example.com/path"')
      expect(html).to include("path</a>.")
      expect(html).not_to include('href="https://example.com/path."')
    end

    it "escapes HTML instead of rendering it" do
      html = described_class.render_html('<script>alert("x")</script> https://safe.com')

      expect(html).to include("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;")
      expect(html).not_to include("<script>")
      expect(html).to include('href="https://safe.com"')
    end

    it "does not link non-http schemes" do
      html = described_class.render_html("javascript:alert(1) and data:text/html,test")

      expect(html).not_to include("<a ")
      expect(html).to include("javascript:alert(1)")
      expect(html).to include("data:text/html,test")
    end

    it "returns an empty string for blank input" do
      expect(described_class.render_html("")).to eq("")
      expect(described_class.render_html(nil)).to eq("")
    end
  end
end
