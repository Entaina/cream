class MqlsController < ApplicationController
  include RequiresFeature
  requires_feature :mql_pool
  skip_after_action :verify_policy_scoped

  def index
    authorize :mql, :index?
    SubscriptionType.ensure_defaults!(current_workspace)

    @filters = mql_filters
    base = Marketing::MqlEligibility.scope(
      workspace: current_workspace,
      subscription_type_id: @filters["subscription_type_id"]
    )
    @people = Marketing::FilterResolver.new(
      workspace: current_workspace,
      record_type: "Person",
      filters: @filters,
      deal_scope: policy_scope(current_workspace.deals)
    ).resolve(
      base.includes(:company, :email_subscriptions, product_interests: :product, lead_submissions: :lead_form)
    ).order(lead_score: :desc, updated_at: :desc)

    @pagy, @people = pagy(:offset, @people)
    @subscription_types = current_workspace.subscription_types.active.order(:name)
    @products = current_workspace.products.ordered
    @lead_forms = current_workspace.lead_forms.ordered
    @pending_interests = pending_interests_by_person
    @open_deals_by_person = visible_open_deals_by_person
    @form_summaries = form_summaries_by_person
  end

  private

  def mql_filters
    raw = params.permit(
      :q, :subscription_type_id, :subscription_status, :open_deal, :open_deal_product_id,
      :interest_product_id, :interest_status, :dealt_product_id, :lead_form_id,
      :capture_destination, :submitted_from, :submitted_to, :lead_score_min, :lead_score_max
    ).to_h.stringify_keys

    raw["marketing_eligible"] = true
    raw["open_deal"] ||= params[:view] == "no_open_deal" ? "no" : "any"
    raw["open_deal_product_id"] = params[:product_id] if params[:product_id].present?
    raw
  end

  def pending_interests_by_person
    Marketing::ProductInterest.pending
      .where(workspace: current_workspace, person_id: @people.map(&:id))
      .includes(:product)
      .group_by(&:person_id)
  end

  def visible_open_deals_by_person
    person_ids = @people.map(&:id)
    return {} if person_ids.empty?

    deals = policy_scope(current_workspace.deals).open_deals
      .joins(:deal_contacts)
      .where(deal_contacts: { person_id: person_ids })
      .includes(:pipeline, :deal_contacts, deal_products: :product)

    result = Hash.new { |hash, key| hash[key] = [] }
    deals.find_each do |deal|
      deal.deal_contacts.each do |contact|
        next unless person_ids.include?(contact.person_id)

        result[contact.person_id] << deal
      end
    end
    result
  end

  def form_summaries_by_person
    LeadSubmission.where(workspace: current_workspace, person_id: @people.map(&:id))
      .includes(:lead_form)
      .group_by(&:person_id)
      .transform_values do |submissions|
        submissions.group_by(&:lead_form_id).filter_map do |_form_id, rows|
          form = rows.first.lead_form
          next if form.nil?

          { form: form, count: rows.size, first_at: rows.map(&:created_at).min, last_at: rows.map(&:created_at).max }
        end
      end
  end
end
