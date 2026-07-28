class ActivePipelinesController < ApplicationController
  FILTERABLE_LISTINGS = {
    "deals#index" => :deals_path,
    "deals#board" => :board_deals_path,
    "people#index" => :people_path,
    "companies#index" => :companies_path
  }.freeze

  def update
    authorize current_workspace, :show?

    pipeline_id = params[:pipeline_id]
    if pipeline_id.blank? || pipeline_id == "all"
      current_membership.update!(current_pipeline_id: nil)
    else
      pipeline = current_workspace.pipelines.find(pipeline_id)
      current_membership.update!(current_pipeline_id: pipeline.id)
    end

    redirect_to safe_return_path
  end

  private

  def safe_return_path
    candidate = resolve_return_path
    listing_key = filterable_listing_key(candidate)
    return candidate unless listing_key

    ListFilterState.delete(
      session: Current.session,
      workspace: current_workspace,
      key: listing_key
    )

    send(FILTERABLE_LISTINGS.fetch(listing_key))
  end

  def resolve_return_path
    return_to = params[:return_to].to_s
    if return_to.start_with?("/") && !return_to.start_with?("//")
      return_to
    else
      request.referer.presence || root_path
    end
  end

  def filterable_listing_key(path)
    path_only = path_without_query(path)

    FILTERABLE_LISTINGS.find do |key, route_helper|
      path_only == send(route_helper)
    end&.first
  end

  def path_without_query(url)
    URI.parse(url.to_s).path
  rescue URI::InvalidURIError
    url.to_s.split("?", 2).first
  end
end
