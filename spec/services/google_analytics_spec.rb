require "rails_helper"

RSpec.describe GoogleAnalytics do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "returns an empty tag without a workspace measurement id" do
    workspace.update!(ga_measurement_id: nil)

    expect(described_class.script_tag(workspace: workspace)).to eq("")
  end

  it "embeds gtag when the workspace has a measurement id" do
    workspace.update!(ga_measurement_id: "G-TEST123")

    html = described_class.script_tag(workspace: workspace)

    expect(html).to include("googletagmanager.com/gtag/js?id=G-TEST123")
    expect(html).to include("gtag('config', 'G-TEST123')")
  end
end
