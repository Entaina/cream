require "rails_helper"

RSpec.describe "Pipelines", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }

  describe "POST /pipelines" do
    it "creates a pipeline with its nested stages" do
      sign_in_as(member)

      expect {
        post pipelines_path, params: { pipeline: { name: "Sales", default_pipeline: "1",
          pipeline_stages_attributes: {
            "0" => { name: "New", color: "hoki", probability: 10 },
            "1" => { name: "Closed", color: "green", probability: 100, won: "1", closed: "1" }
          } } }
      }.to change(Pipeline, :count).by(1).and change(PipelineStage, :count).by(2)

      expect(response).to redirect_to(pipelines_path)
      expect(Pipeline.last.pipeline_stages.ordered.map(&:name)).to eq(%w[New Closed])
    end
  end

  describe "POST /pipelines/:id/duplicate" do
    it "duplicates the pipeline structure without its deals" do
      sign_in_as(member)
      source = Pipeline.create_default!(workspaces(:one))
      create_deal!(workspaces(:one), pipeline: source)

      expect {
        post duplicate_pipeline_path(source)
      }.to change(Pipeline, :count).by(1).and change(PipelineStage, :count).by(source.pipeline_stages.count)

      copy = Pipeline.order(:id).last
      expect(copy.name).to eq("Ventas (copy)")
      expect(copy.deals).to be_empty
      expect(response).to redirect_to(edit_pipeline_path(copy))
    end
  end

  describe "PATCH /pipelines/:id" do
    it "reorders stages by position" do
      sign_in_as(member)
      pipeline = Pipeline.create_default!(workspaces(:one))
      lead, qualified, proposal = pipeline.pipeline_stages.ordered.first(3)

      patch pipeline_path(pipeline), params: {
        pipeline: {
          name: pipeline.name,
          pipeline_stages_attributes: pipeline.pipeline_stages.ordered.each_with_index.to_h { |stage, i|
            position = case stage.id
            when proposal.id then 0
            when lead.id then 1
            when qualified.id then 2
            else stage.position
            end
            [ i.to_s, {
              id: stage.id,
              name: stage.name,
              color: stage.color,
              probability: stage.probability,
              position: position,
              won: stage.won ? "1" : "0",
              closed: stage.closed ? "1" : "0"
            } ]
          }
        }
      }

      expect(response).to redirect_to(pipelines_path)
      expect(pipeline.reload.pipeline_stages.ordered.first(3).map(&:name)).to eq(%w[Proposal Lead Qualified])
    end
  end

  describe "PATCH /pipelines/:id/reorder_stages" do
    it "reorders stages by id list" do
      sign_in_as(member)
      pipeline = Pipeline.create_default!(workspaces(:one))
      stages = pipeline.pipeline_stages.ordered.to_a
      new_order = [ stages[2].id, stages[0].id, stages[1].id ] + stages.drop(3).map(&:id)

      patch reorder_stages_pipeline_path(pipeline),
        params: { stage_ids: new_order },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(pipeline.reload.pipeline_stages.ordered.pluck(:id)).to eq(new_order)
    end

    it "rejects an incomplete stage list" do
      sign_in_as(member)
      pipeline = Pipeline.create_default!(workspaces(:one))

      patch reorder_stages_pipeline_path(pipeline),
        params: { stage_ids: [ pipeline.pipeline_stages.ordered.first.id ] },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /pipelines validation" do
    it "rejects a pipeline without stages" do
      sign_in_as(member)

      expect {
        post pipelines_path, params: { pipeline: { name: "Empty" } }
      }.not_to change(Pipeline, :count)
    end
  end
end
