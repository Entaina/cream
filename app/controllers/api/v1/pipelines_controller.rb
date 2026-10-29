module Api
  module V1
    class PipelinesController < BaseController
      def index
        pipelines = policy_scope(current_workspace.pipelines).ordered.includes(:pipeline_stages)
        pipelines = api_page(pipelines.order(:id))
        render json: pipelines.map { |pipeline| pipeline_json(pipeline) }
      end

      def show
        pipeline = policy_scope(current_workspace.pipelines).includes(:pipeline_stages).find(params[:id])
        authorize pipeline
        render json: pipeline_json(pipeline)
      end

      private

      def pipeline_json(pipeline)
        {
          id: pipeline.id,
          name: pipeline.name,
          default: pipeline.default_pipeline,
          position: pipeline.position,
          stages: pipeline.pipeline_stages.ordered.map { |stage| stage_json(stage) },
          created_at: pipeline.created_at.iso8601,
          updated_at: pipeline.updated_at.iso8601
        }
      end

      def stage_json(stage)
        {
          id: stage.id,
          name: stage.name,
          position: stage.position,
          probability: stage.probability,
          won: stage.won,
          closed: stage.closed,
          color: stage.color
        }
      end
    end
  end
end
