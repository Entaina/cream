require "rails_helper"

RSpec.describe "StageConditions", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:stage) { pipeline.pipeline_stages.find_by!(name: "Qualified") }

  before { sign_in_as(member) }

  def create_condition(**attrs)
    workspace.stage_conditions.create!({pipeline_stage: stage, field: "value",
                                        operator: "gt", compare_value: "1000"}.merge(attrs))
  end

  it "lists the conditions of a stage" do
    create_condition
    get pipeline_stage_stage_conditions_path(stage)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Importe")
    expect(response.body).to include(I18n.t("stage_conditions.index.new"))
  end

  it "renders in English when the user locale is en" do
    create_condition
    member.update!(locale: "en")
    get pipeline_stage_stage_conditions_path(stage)
    expect(response.body).to include(I18n.t("stage_conditions.index.new", locale: :en))
    expect(response.body).not_to include(I18n.t("stage_conditions.index.new", locale: :es))
  ensure
    member.update!(locale: "es")
  end

  it "creates a condition" do
    expect {
      post pipeline_stage_stage_conditions_path(stage), params: {
        stage_condition: {field: "value", operator: "gt", compare_value: "1000", active: "1"}
      }
    }.to change(StageCondition, :count).by(1)

    condition = StageCondition.order(:id).last
    expect(condition.workspace).to eq(workspace)
    expect(condition.pipeline_stage).to eq(stage)
  end

  it "rejects an invalid condition" do
    post pipeline_stage_stage_conditions_path(stage), params: {
      stage_condition: {field: "value", operator: "gt", compare_value: ""}
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "updates and destroys a condition" do
    condition = create_condition
    patch stage_condition_path(condition), params: {stage_condition: {compare_value: "2000"}}
    expect(condition.reload.compare_value).to eq("2000")

    expect { delete stage_condition_path(condition) }.to change(StageCondition, :count).by(-1)
  end

  it "isolates workspaces" do
    other_pipeline = Pipeline.create_default!(workspaces(:two))
    get pipeline_stage_stage_conditions_path(other_pipeline.pipeline_stages.second)
    expect(response).to have_http_status(:not_found)
  end
end
