module LeadFormTemplates
  module Drops
    class ProductDrop < Liquid::Drop
      def initialize(product)
        @product = product
      end

      def blank?
        @product.blank?
      end

      def id
        @product&.id
      end
    end
  end
end
