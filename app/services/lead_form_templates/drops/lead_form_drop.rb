module LeadFormTemplates
  module Drops
    class LeadFormDrop < Liquid::Drop
      delegate :name, :slug, :template_key, :collects_company?, to: :@lead_form

      def initialize(lead_form)
        @lead_form = lead_form
      end

      def collects_company
        @lead_form.collects_company?
      end
    end
  end
end
