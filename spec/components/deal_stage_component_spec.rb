# frozen_string_literal: true

require "rails_helper"

RSpec.describe DealStageComponent, type: :component do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, stage: pipeline.pipeline_stages.find_by!(name: "Proposal")) }

  def render_component(**options)
    render_inline(DealStageComponent.new(deal: deal, **options))
  end

  it "renders a read-only badge when not editable" do
    render_component(editable: false)

    expect(page).to have_css("span.inline-flex.rounded-full", text: "Proposal")
    expect(page).not_to have_css('[data-controller="dropdown"]')
    expect(page).not_to have_css("button")
  end

  it "renders a dropdown with move forms for each stage when editable" do
    render_component(editable: true)

    expect(page).to have_css('[data-controller="dropdown"] button[aria-haspopup="menu"]')
    pipeline.pipeline_stages.ordered.each do |stage|
      expect(page).to have_text(stage.name)
    end
    expect(rendered_content).to include("source=inline")
    expect(rendered_content.scan(/<form/).size).to eq(pipeline.pipeline_stages.count - 1)
    expect(rendered_content).to include('aria-current="true"')
  end

  it "wraps output when wrapper_id is given" do
    render_component(editable: false, wrapper_id: "deal_stage_badge")

    expect(page).to have_css("#deal_stage_badge")
  end

  it "disables stages whose entry conditions are not met" do
    target = pipeline.pipeline_stages.find_by!(name: "Qualified")
    workspace.stage_conditions.create!(pipeline_stage: target, field: "value", operator: "gt", compare_value: "10000")
    deal.update_column(:value, 100)

    render_component(editable: true)

    expect(rendered_content).to match(/button[^>]*disabled[^>]*title="[^"]+"/)
    expect(rendered_content).not_to include("pipeline_stage_id=#{target.id}")
  end

  it "enables a stage when its entry conditions are met" do
    target = pipeline.pipeline_stages.find_by!(name: "Qualified")
    workspace.stage_conditions.create!(pipeline_stage: target, field: "value", operator: "gt", compare_value: "100")
    deal.update_column(:value, 500)

    render_component(editable: true)

    expect(rendered_content).to include("pipeline_stage_id=#{target.id}")
    expect(rendered_content).to include("source=inline")
  end
end
