module Api
  module V1
    module Marketing
      class LeadFormsController < BaseController
        def index
          authorize LeadForm.new(workspace: current_workspace), :index?
          forms = policy_scope(current_workspace.lead_forms).ordered.limit(list_limit)
          render json: forms.map { |form| ::Marketing::ApiPresenter.lead_form_json(form) }
        end
      end
    end
  end
end
