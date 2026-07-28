class AiSearchController < ApplicationController
  include RequiresFeature

  requires_feature :ai_assistant

  def index
    authorize current_workspace, :search?

    @query = params[:q].to_s.strip
    result = Ai::NaturalLanguageSearch.new(
      workspace: current_workspace,
      query: @query,
      people_scope: policy_scope(current_workspace.people),
      companies_scope: policy_scope(current_workspace.companies),
      deals_scope: policy_scope(current_workspace.deals),
      tasks_scope: policy_scope(current_workspace.tasks)
    ).call

    @interpretation = result.interpretation
    @people = result.people
    @companies = result.companies
    @deals = result.deals
    @tasks = result.tasks
    @emails = result.emails
  end
end
