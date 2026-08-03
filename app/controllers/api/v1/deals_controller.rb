module Api
  module V1
    class DealsController < BaseController
      def index
        deals = policy_scope(current_workspace.deals).includes(:company, :pipeline_stage)
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

        if deal.save
          render json: deal_json(deal), status: :created
        else
          render json: { errors: deal.errors.full_messages }, status: :unprocessable_entity
        end
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
        params.require(:deal).permit(:name, :company_id, :pipeline_id, :pipeline_stage_id, :value, :currency, :probability, :expected_close_date)
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

      def deal_json(deal)
        {
          id: deal.id,
          name: deal.name,
          stage: deal.stage_label,
          value: deal.value.to_f,
          currency: deal.currency,
          company_id: deal.company_id,
          created_at: deal.created_at.iso8601,
          updated_at: deal.updated_at.iso8601
        }
      end
    end
  end
end
