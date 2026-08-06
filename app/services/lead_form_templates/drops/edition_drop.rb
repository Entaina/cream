module LeadFormTemplates
  module Drops
    class EditionDrop < Liquid::Drop
      def initialize(edition)
        @edition = edition
      end

      def id
        @edition.id
      end

      def display_name
        @edition.display_name
      end
    end
  end
end
