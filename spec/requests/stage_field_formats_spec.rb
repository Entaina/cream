require "rails_helper"

RSpec.describe "StageFieldFormats", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:stage) { pipeline.first_stage }

  before { sign_in_as(member) }

  def create_format(**attrs)
    workspace.stage_field_formats.create!({ pipeline_stage: stage, field: "value",
      operator: "eq", compare_value: "0", display_text: "guest" }.merge(attrs))
  end

  it "lists the formats of a stage" do
    create_format
    get pipeline_stage_stage_field_formats_path(stage)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("guest")
  end

  it "creates a format" do
    expect {
      post pipeline_stage_stage_field_formats_path(stage), params: {
        stage_field_format: { field: "value", operator: "eq", compare_value: "0",
                              display_text: "guest", active: "1" }
      }
    }.to change(StageFieldFormat, :count).by(1)

    format = StageFieldFormat.order(:id).last
    expect(format.workspace).to eq(workspace)
    expect(format.pipeline_stage).to eq(stage)
  end

  it "rejects an invalid format" do
    post pipeline_stage_stage_field_formats_path(stage), params: {
      stage_field_format: { field: "value", operator: "eq", compare_value: "0", display_text: "" }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "updates and destroys a format" do
    format = create_format
    patch stage_field_format_path(format), params: { stage_field_format: { display_text: "invitado" } }
    expect(format.reload.display_text).to eq("invitado")

    expect { delete stage_field_format_path(format) }.to change(StageFieldFormat, :count).by(-1)
  end

  it "isolates workspaces" do
    other_pipeline = Pipeline.create_default!(workspaces(:two))
    get pipeline_stage_stage_field_formats_path(other_pipeline.first_stage)
    expect(response).to have_http_status(:not_found)
  end

  describe "applied in deal views" do
    let(:deal) { create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Curso gratis") }

    before do
      create_format
      deal.update_column(:value, 0)
    end

    it "shows the override on the deal page" do
      get deal_path(deal)
      expect(response.body).to include("guest")
    end

    it "shows the override in the deals table" do
      get deals_path
      expect(response.body).to include("guest")
    end

    it "refreshes the value when moving stages from the show page" do
      target = pipeline.pipeline_stages.find_by(name: "Qualified")
      patch move_deal_path(deal), params: { pipeline_stage_id: target.id, source: "show" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include("deal_value_display_#{deal.id}")
      expect(response.body).not_to include("guest") # Qualified has no format rule
    end

    it "refreshes the card value when moving on the board" do
      target = pipeline.pipeline_stages.find_by(name: "Qualified")
      patch move_deal_path(deal), params: { pipeline_stage_id: target.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include("deal_card_value_#{deal.id}")
    end
  end
end
