module Api
  module V1
    class ProductsController < BaseController
      def index
        products = policy_scope(current_workspace.products).ordered.includes(:editions)
        products = products.search(params[:q]) if params[:q].present?
        products = products.with_segment(params[:segment]) if params[:segment].present?
        products = api_page(products.order(:id))
        render json: products.map { |product| product_json(product) }
      end

      def show
        product = policy_scope(current_workspace.products).includes(:editions).find(params[:id])
        authorize product
        render json: product_json(product)
      end

      private

      def product_json(product)
        {
          id: product.id,
          name: product.name,
          price: product.price.to_f,
          description: product.description,
          segment: product.segment,
          editions: product.editions.ordered.map { |edition| edition_json(edition) },
          created_at: product.created_at.iso8601,
          updated_at: product.updated_at.iso8601
        }.compact
      end

      def edition_json(edition)
        {
          id: edition.id,
          name: edition.name,
          starts_on: edition.starts_on&.iso8601,
          ends_on: edition.ends_on&.iso8601
        }.compact
      end
    end
  end
end
