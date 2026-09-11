module Api
  module V1
    module Marketing
      class EmailTemplatesController < BaseController
        requires_feature :email_templates

        def index
          authorize EmailTemplate.new(workspace: current_workspace, user: current_user), :index?
          templates = policy_scope(current_workspace.email_templates).visible_to(current_user).ordered.limit(list_limit)
          render json: templates.map { |template| ::Marketing::ApiPresenter.email_template_json(template) }
        end
      end
    end
  end
end
