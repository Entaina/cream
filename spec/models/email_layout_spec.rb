require "rails_helper"

RSpec.describe EmailLayout, type: :model do
  fixtures :users, :workspaces, :companies

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme)) }

  it "requires a content placeholder" do
    layout = workspace.email_layouts.build(name: "Bad", body: "<html><body>No slot</body></html>")
    expect(layout).not_to be_valid
    expect(layout.errors[:body]).to include("must include {{ content }} or {content}")
  end

  it "accepts liquid content placeholder" do
    layout = workspace.email_layouts.create!(name: "Good", body: "<html><body>{{ content }}</body></html>")
    rendered = layout.render_with("<p>Hi</p>", record: person, extra_tokens: {})
    expect(rendered).to include("<p>Hi</p>")
  end
end
