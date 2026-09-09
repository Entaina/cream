require "rails_helper"

RSpec.describe StageNameGroup do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }

  it "groups stages by name preserving first-seen order" do
    other = pipeline.duplicate(name: "Partners").tap(&:save!)
    stages = workspace.pipeline_stages.ordered_across_pipelines.to_a

    groups = described_class.group(stages)

    expect(groups.map(&:name)).to eq([ "Lead", "Qualified", "Proposal", "Negotiation", "Won", "Lost" ])
    expect(groups.first.stages.map(&:pipeline).map(&:name)).to contain_exactly(pipeline.name, other.name)
  end

  it "builds segments ordered by pipeline position with counts" do
    other = pipeline.duplicate(name: "Partners").tap(&:save!)
    lead_default = pipeline.pipeline_stages.find_by!(name: "Lead")
    lead_other = other.pipeline_stages.find_by!(name: "Lead")
    create_deal!(workspace, pipeline: pipeline, stage: lead_default)
    create_deal!(workspace, pipeline: other, stage: lead_other)
    create_deal!(workspace, pipeline: other, stage: lead_other)

    grouper = described_class.new(workspace.pipeline_stages.ordered_across_pipelines.to_a)
    group = grouper.groups.first
    segments = grouper.segments_for(group, { lead_default.id => 1, lead_other.id => 2 })

    expect(segments.map(&:pipeline_name)).to eq([ pipeline.name, other.name ])
    expect(segments.map(&:value)).to eq([ 1, 2 ])
    expect(segments.first.color).to eq("bg-hoki-600 dark:bg-hoki-400")
    expect(segments.second.color).to eq("bg-copperfield-600 dark:bg-copperfield-400")
  end
end
