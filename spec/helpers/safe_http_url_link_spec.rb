require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#safe_http_url_link" do
    it "links http URLs in a new tab without leaking the opener" do
      html = Nokogiri::HTML.fragment(helper.safe_http_url_link("https://example.com/a?b=1"))
      link = html.at_css("a")

      expect(link["href"]).to eq("https://example.com/a?b=1")
      expect(link["target"]).to eq("_blank")
      expect(link["rel"]).to eq("noopener noreferrer")
    end

    it "uses the given label as link text" do
      link = Nokogiri::HTML.fragment(helper.safe_http_url_link("https://linkedin.com/in/ana", "Ver perfil")).at_css("a")

      expect(link.text).to eq("Ver perfil")
      expect(link["href"]).to eq("https://linkedin.com/in/ana")
    end

    it "shows script URLs as plain text" do
      html = helper.safe_http_url_link("javascript:alert(1)")

      expect(html).not_to include("<a")
      expect(html).to eq("javascript:alert(1)")
    end

    it "escapes values that are not URLs" do
      html = helper.safe_http_url_link("<img src=x onerror=alert(1)>")

      expect(html).not_to include("<img")
      expect(html).to include("&lt;img")
    end
  end
end
