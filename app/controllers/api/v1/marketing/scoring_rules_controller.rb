module Api
  module V1
    module Marketing
      class ScoringRulesController < BaseController
        requires_feature :lead_scoring

        def index
          authorize ScoringRule.new(workspace: current_workspace), :index?
          rules = policy_scope(current_workspace.scoring_rules).ordered
          render json: rules.map { |rule| ::Marketing::ApiPresenter.scoring_rule_json(rule) }
        end
      end
    end
  end
end
