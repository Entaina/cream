class SearchController < ApplicationController
  def index
    authorize current_workspace, :search?
    @query = params[:q].to_s.strip
    people_scope = policy_scope(current_workspace.people)
    companies_scope = policy_scope(current_workspace.companies)
    deals_scope = policy_scope(current_workspace.deals)

    if @query.present?
      @people = people_scope.search(@query).includes(:company).limit(8)
      @companies = companies_scope.search(@query).limit(8)
      @deals = deals_scope.search(@query).includes(:company).limit(8)
    else
      @people = @companies = @deals = []
    end
  end
end
