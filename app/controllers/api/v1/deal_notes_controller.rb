module Api
  module V1
    class DealNotesController < BaseController
      def create
        deal = policy_scope(current_workspace.deals).find(params[:deal_id])
        note = deal.notes.new(note_params.merge(workspace: current_workspace, user: current_user))
        authorize note

        if note.save
          render json: note_json(note), status: :created
        else
          render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def note_params
        params.require(:note).permit(:title, :body)
      end

      def note_json(note)
        {
          id: note.id,
          title: note.title,
          body: note.body,
          created_at: note.created_at.iso8601,
          updated_at: note.updated_at.iso8601
        }
      end
    end
  end
end
