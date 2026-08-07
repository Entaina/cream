module Api
  module V1
    class DealsController < BaseController
      def index
        deals = policy_scope(current_workspace.deals).includes(:company, :pipeline_stage, :contacts)
        deals = deals.search(params[:q]) if params[:q].present?
        render json: deals.map { |deal| deal_json(deal) }
      end

      def show
        deal = policy_scope(current_workspace.deals).find(params[:id])
        authorize deal
        render json: deal_json(deal)
      end

      def create
        deal = current_workspace.deals.new(deal_params.merge(owner: current_user))
        authorize deal

        notes = []
        ActiveRecord::Base.transaction do
          deal.save!
          notes = create_notes_for!(deal)
        end
        render json: deal_json(deal, notes: notes), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        deal = policy_scope(current_workspace.deals).find(params[:id])
        authorize deal

        attrs = deal_params
        new_stage = extract_stage_change(deal, attrs)
        if deal.update(attrs)
          deal.move_to_stage!(new_stage) if new_stage
          render json: deal_json(deal)
        else
          render json: { errors: deal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        deal = policy_scope(current_workspace.deals).find(params[:id])
        authorize deal
        deal.destroy
        head :no_content
      end

      private

      def deal_params
        raw = params.require(:deal)
        permitted = raw.permit(
          :name, :company_id, :pipeline_id, :pipeline_stage_id, :value, :currency, :probability, :expected_close_date,
          contact_ids: [],
          tasks_attributes: %i[title due_on]
        )
        permitted[:contact_ids] = resolve_contact_ids(permitted[:contact_ids]) if raw.key?(:contact_ids)
        permitted
      end

      def resolve_contact_ids(ids)
        requested = Array(ids).map(&:to_i).uniq
        allowed = policy_scope(current_workspace.people).where(id: requested).pluck(:id)
        return allowed if allowed.size == requested.size

        raise ActiveRecord::RecordNotFound
      end

      def nested_notes_params
        Array(params[:notes]).filter_map do |entry|
          next unless entry.is_a?(ActionController::Parameters) || entry.is_a?(Hash)

          entry = ActionController::Parameters.new(entry) unless entry.is_a?(ActionController::Parameters)
          entry.permit(:title, :body).to_h.symbolize_keys.presence
        end
      end

      def create_notes_for!(deal)
        nested_notes_params.map do |attrs|
          deal.notes.create!(attrs.merge(workspace: current_workspace, user: current_user))
        end
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

      # Stage changes must go through move_to_stage! so the stage_changed
      # activity, webhooks, automations and stage triggers fire.
      def extract_stage_change(deal, attrs)
        stage_id = attrs[:pipeline_stage_id].presence
        return nil if stage_id.nil? || stage_id.to_i == deal.pipeline_stage_id

        attrs.delete(:pipeline_stage_id)
        attrs.delete(:pipeline_id)
        current_workspace.pipeline_stages.find(stage_id)
      end

      def deal_json(deal, notes: nil)
        json = {
          id: deal.id,
          name: deal.name,
          stage: deal.stage_label,
          value: deal.value.to_f,
          currency: deal.currency,
          company_id: deal.company_id,
          contact_ids: deal.contact_ids,
          created_at: deal.created_at.iso8601,
          updated_at: deal.updated_at.iso8601
        }
        json[:notes] = notes.map { |note| note_json(note) } unless notes.nil?
        json
      end
    end
  end
end
