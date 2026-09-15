module Api
  module V1
    class GmailContextsController < BaseController
      requires_feature :gmail_addon

      def show
        render json: {
          selected_workspace_id: current_workspace.id,
          workspaces: available_workspaces.map { |workspace| workspace_json(workspace) }
        }
      end

      private

      def available_workspaces
        current_user.workspaces.order(:name, :id).includes(pipelines: :pipeline_stages)
      end

      def workspace_json(workspace)
        {
          id: workspace.id,
          name: workspace.name,
          default_pipeline_id: default_pipeline_id_for(workspace),
          pipelines: workspace.pipelines.ordered.map { |pipeline| pipeline_json(pipeline) }
        }
      end

      def default_pipeline_id_for(workspace)
        membership = memberships_by_workspace_id[workspace.id]
        membership&.current_pipeline_id || Pipeline.default_for(workspace)&.id
      end

      def memberships_by_workspace_id
        @memberships_by_workspace_id ||= current_user.memberships.index_by(&:workspace_id)
      end

      def pipeline_json(pipeline)
        {
          id: pipeline.id,
          name: pipeline.name,
          default: pipeline.default_pipeline?,
          stages: pipeline.pipeline_stages.map do |stage|
            {id: stage.id, name: stage.name, closed: stage.closed?}
          end
        }
      end
    end
  end
end
