require "rails_helper"

RSpec.describe StageTriggers::MarkdownRenderer do
  it "renders basic markdown" do
    html = described_class.render("**Hola** _mundo_\n\n- uno\n- dos")
    expect(html).to include("<strong>Hola</strong>")
    expect(html).to include("<em>mundo</em>")
    expect(html).to include("<li>uno</li>")
  end

  it "strips script tags and event handlers" do
    html = described_class.render("Hola <script>alert(1)</script> <img src=x onerror=alert(1)>")
    expect(html).not_to include("<script")
    expect(html).not_to include("onerror")
    expect(html).not_to include("<img")
  end

  it "keeps links but only with an href" do
    html = described_class.render("[web](https://example.com)")
    expect(html).to include('href="https://example.com"')
    expect(html).not_to include("javascript:")
  end

  it "neutralises javascript: links" do
    html = described_class.render("[x](javascript:alert(1))")
    expect(html).not_to include("javascript:")
  end

  it "returns an empty string for blank input" do
    expect(described_class.render(nil)).to eq("")
    expect(described_class.render("")).to eq("")
  end
end
