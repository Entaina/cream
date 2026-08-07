module Api
  module V1
    class DealsController < BaseController
      def index
        deals = policy_scope(current_workspace.deals).includes(:company, :pipeline_stage, :contacts,
          deal_products: [ :product, :edition ])
        deals = deals.search(params[:q]) if params[:q].present?
        render json: deals.map { |deal| deal_json(deal) }
      end

      def show
        deal = policy_scope(current_workspace.deals).includes(deal_products: [ :product, :edition ]).find(params[:id])
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
        render json: deal_json(deal.reload, notes: notes), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        deal = policy_scope(current_workspace.deals).find(params[:id])
        authorize deal

        attrs = deal_params(deal: deal)
        new_stage = extract_stage_change(deal, attrs)
        if deal.update(attrs)
          deal.move_to_stage!(new_stage) if new_stage
          render json: deal_json(deal.reload)
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

      def deal_params(deal: nil)
        raw = params.require(:deal)
        permitted = raw.permit(
          :name, :company_id, :pipeline_id, :pipeline_stage_id, :value, :currency, :probability, :expected_close_date,
          contact_ids: [],
          tasks_attributes: %i[title due_on],
          deal_products_attributes: [ :id, :product_id, :edition_id, :edition_name, :quantity, :unit_price, :_destroy ]
        )
        permitted[:contact_ids] = resolve_contact_ids(permitted[:contact_ids]) if raw.key?(:contact_ids)
        if raw.key?(:deal_products_attributes)
          permitted[:deal_products_attributes] = resolve_deal_products_attributes(permitted[:deal_products_attributes], deal: deal)
        end
        permitted
      end

      def resolve_deal_products_attributes(lines, deal: nil)
        normalize_nested_attribute_lines(lines).map do |line|
          attrs = line.to_h.symbolize_keys

          if ActiveModel::Type::Boolean.new.cast(attrs[:_destroy])
            raise ActiveRecord::RecordNotFound unless attrs[:id].present? && deal&.deal_products&.exists?(attrs[:id])

            line_item = deal.deal_products.find(attrs[:id])
            attrs[:product_id] ||= line_item.product_id
            next attrs
          end

          if attrs[:product_id].present?
            product = policy_scope(current_workspace.products).find(attrs[:product_id])
            attrs[:edition_id] = resolve_edition_id(product, attrs[:edition_id]) if attrs[:edition_id].present?
            attrs
          elsif attrs[:id].present?
            raise ActiveRecord::RecordNotFound unless deal

            line_item = deal.deal_products.find(attrs[:id])
            attrs[:product_id] ||= line_item.product_id
            attrs[:edition_id] = resolve_edition_id(line_item.product, attrs[:edition_id]) if attrs[:edition_id].present?
            attrs
          else
            raise ActiveRecord::RecordNotFound
          end
        end
      end

      def resolve_edition_id(product, edition_id)
        product.editions.find(edition_id).id
      end

      def normalize_nested_attribute_lines(lines)
        return [] if lines.blank?

        lines.is_a?(Hash) ? lines.sort_by { |key, _| key.to_s.to_i }.map(&:last) : Array(lines)
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
          deal_products: deal.deal_products.map { |line| deal_product_json(line) },
          created_at: deal.created_at.iso8601,
          updated_at: deal.updated_at.iso8601
        }
        json[:notes] = notes.map { |note| note_json(note) } unless notes.nil?
        json
      end

      def deal_product_json(line)
        {
          id: line.id,
          product_id: line.product_id,
          product_name: line.product.name,
          edition_id: line.edition_id,
          edition_name: line.edition&.name,
          quantity: line.quantity,
          unit_price: line.unit_price.to_f,
          subtotal: line.subtotal.to_f
        }.compact
      end
    end
  end
end
