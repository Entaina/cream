class PeopleController < ApplicationController
  include ViewScoped
  include Filterable

  remembers_list_filters only: :index

  before_action :set_person, only: %i[show edit update destroy merge toggle_subscription]
  before_action :set_edit_section, only: %i[edit update]

  SORTABLE = %w[first_name last_name email job_title location created_at].freeze

  def index
    load_saved_views("Person")
    @people = policy_scope(current_workspace.people).includes(:company, :owner, :person_emails, custom_field_values: :custom_field)
    @people = @people.search(filter_value(:q))
    @people = ListFilters.apply_company(@people, filter_value(:company_id)) if filter_value(:company_id).present?
    @people = ListFilters.apply_owner(@people, filter_value(:owner_id)) if filter_value(:owner_id).present?
    @people = ListFilters.apply_created_at(@people, @effective_filters)
    @people = @people.where(lifecycle_stage: params[:lifecycle_stage]) if params[:lifecycle_stage].present?
    if params[:lifecycle_stage_in].present?
      @people = @people.where(lifecycle_stage: Array(params[:lifecycle_stage_in]))
    end
    if params[:utm_source].present?
      @people = @people.joins(:lead_submissions)
        .where("lead_submissions.metadata->>'utm_source' = ?", params[:utm_source])
        .distinct
    end
    @people = @people.merge(Person.apply_custom_field_filters(current_workspace, filter_value(:cf)))
    @people = apply_sorting(@people, sortable: SORTABLE, default_column: "first_name")
    @companies = current_workspace.companies.order(:name)
    @owners = current_workspace.users.order(:name)
    @custom_fields = current_workspace.custom_fields.where(record_type: "Person").ordered
    @duplicate_group_count = PersonDuplicateGroups.call(current_workspace).size

    respond_to do |format|
      # JSON powers the inline-select autocomplete and must return all matches (unpaginated).
      format.json { render json: @people.map { |p| person_picker_json(p) } }
      format.html { @pagy, @people = pagy(:offset, @people) }
    end
  end

  def show
    authorize @person
    deals_scope = policy_scope(current_workspace.deals)
      .joins(:contacts)
      .where(people: {id: @person.id})
      .distinct
    @deal_product_options = current_workspace.products
      .where(id: DealProduct.where(deal_id: deals_scope.select(:id)).select(:product_id))
      .order(:name)
    @deal_product_id = params[:product_id].presence
    deals = if @deal_product_id
      deals_scope.joins(:deal_products).where(deal_products: {product_id: @deal_product_id}).distinct
    else
      deals_scope
    end
    @deals = deals.includes(:pipeline_stage, :products).order(created_at: :desc)
    @person_tab = params[:tab].presence_in(%w[activity deals information files]) || (@deal_product_id ? "deals" : "activity")
    @person_tab = "activity" if @person_tab == "files" && !CreamFeatures.enabled?(:attachments)
    @pending_tasks = @person.tasks.pending.includes(:assignee).due_order
    @completed_tasks = @person.tasks.completed.includes(:assignee).order(completed_at: :desc)
    if CreamFeatures.enabled?(:marketing_campaigns)
      @person_campaign_messages = @person.email_messages
        .from_campaigns
        .includes(:campaign, :email_events)
        .recent_first
        .limit(EmailMessage::CAMPAIGN_HISTORY_LIMIT)
        .to_a
    end
    if CreamFeatures.enabled?(:journeys)
      @person_journey_enrollments = @person.journey_enrollments
        .includes(:journey, :current_step)
        .order(enrolled_at: :desc)
        .limit(JourneyEnrollment::HISTORY_LIMIT)
        .to_a
    end
    @activity_feed = RecordActivityFeed.new(@person, filter: params[:activity_filter], page: params[:activity_page],
      emails: CreamFeatures.enabled?(:record_email), comments: CreamFeatures.enabled?(:comments))
    @okm_chat_record = @person
    @note = Note.new
    @comment = Comment.new
    @email_message = EmailMessage.new(to_address: @person.email)
    @task = Task.new(due_on: Task.default_due_on)
  end

  def new
    @person = current_workspace.people.new(company_id: params[:company_id])
    authorize @person
  end

  def create
    @person = current_workspace.people.new(person_params)
    authorize @person
    @person.owner ||= current_user

    if @person.save
      respond_to do |format|
        format.html { redirect_to @person, notice: t("flashes.people.created") }
        format.json { render json: {id: @person.id, name: @person.display_name}, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: {errors: @person.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @person
    if @person.person_emails.empty? && @person.email.present?
      @person.person_emails.build(address: @person.email, primary: true, workspace: current_workspace)
    end
  end

  def update
    authorize @person

    if inline_edit?
      update_inline
    elsif @person.update(person_params)
      redirect_to @edit_section ? person_path(@person, tab: "information") : person_path(@person), notice: t("flashes.people.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @person
    @person.destroy
    redirect_to people_path, notice: t("flashes.people.deleted"), status: :see_other
  end

  def duplicates
    authorize Person, :index?
    @groups = PersonDuplicateGroups.call(current_workspace)
  end

  def merge
    authorize @person, :merge?
    load_merge_candidates

    if request.post?
      @selected_secondary_ids = merge_params[:secondary_ids].to_a.map(&:to_i).uniq - [@person.id]
      secondaries = policy_scope(current_workspace.people)
        .where(id: @selected_secondary_ids)
        .includes(:owner, :deals, :company, :person_emails)
        .to_a

      if secondaries.empty?
        flash.now[:alert] = t("people.merge.errors.no_secondaries")
        return render :merge, status: :unprocessable_entity
      end

      PersonMerger.call(primary: @person, secondaries: secondaries, user: current_user)
      redirect_to @person, notice: t("flashes.people.merged", count: secondaries.size, name: @person.display_name), status: :see_other
    else
      @selected_secondary_ids = Array(params[:secondary_ids]).map(&:to_i).uniq - [@person.id]
    end
  rescue PersonMerger::Error => e
    flash.now[:alert] = e.message
    render :merge, status: :unprocessable_entity
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[PeopleController#merge] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    flash.now[:alert] = "Could not merge contacts. Please try again or contact support."
    render :merge, status: :unprocessable_entity
  end

  def toggle_subscription
    authorize @person, :update?
    SubscriptionType.ensure_defaults!(current_workspace)
    type = current_workspace.subscription_types.find(params[:subscription_type_id])
    subscription = EmailSubscription.find_by(person: @person, subscription_type: type)

    if subscription&.subscribed?
      Marketing::ConsentService.unsubscribe!(person: @person, subscription_type: type, source: "crm_admin")
    else
      Marketing::ConsentService.subscribe!(person: @person, subscription_type: type, source: "crm_admin", legal_basis: "consent")
    end

    redirect_to @person, notice: t("flashes.people.subscription_updated")
  end

  private

  def set_edit_section
    @edit_section = params[:section].presence_in(%w[contact profile management custom])
  end

  def set_person
    @person = policy_scope(current_workspace.people).includes(:person_emails).find(params[:id])
  end

  def load_merge_candidates
    scope = policy_scope(current_workspace.people).where.not(id: @person.id)

    email_addresses = @person.person_emails.pluck(:address).map { |address| address.downcase.strip }
    email_addresses << @person.email.downcase.strip if @person.email.present?
    email_addresses.uniq!

    @merge_candidates = if email_addresses.any?
      scope.left_joins(:person_emails).where(
        "people.company_id = :company_id OR LOWER(TRIM(people.email)) IN (:emails) OR LOWER(TRIM(person_emails.address)) IN (:emails)",
        company_id: @person.company_id,
        emails: email_addresses
      )
    else
      scope.where(company_id: @person.company_id)
    end.includes(:owner, :deals, :company, :person_emails)
      .order(:first_name, :last_name, :id)
      .distinct
  end

  def merge_params
    params.permit(secondary_ids: [])
  end

  def person_picker_json(person)
    {
      id: person.id,
      name: person.display_name,
      hint: [person.company&.name, person.email].compact_blank.join(" · ").presence
    }
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :phone, :job_title, :location,
      :linkedin_url, :twitter_url, :description, :company_id, :owner_id, :source, :first_contact_on, :brought_by_id,
      custom_fields: {},
      person_emails_attributes: [:id, :address, :primary, :_destroy])
  end

  INLINE_EDIT_FIELDS = %w[company_id owner_id].freeze

  def inline_edit?
    INLINE_EDIT_FIELDS.include?(params[:inline_edit].to_s)
  end

  def inline_field
    params[:inline_edit].to_s
  end

  def inline_cell_dom_id
    "person_#{@person.id}_#{inline_field}"
  end

  def update_inline
    attrs = inline_person_params
    if @person.update(attrs)
      @person.reload
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            inline_cell_dom_id,
            partial: "people/inline_edit_cell",
            locals: {person: @person, field: inline_field, editing: false}
          )
        end
        format.html { redirect_to people_path, notice: t("flashes.people.updated") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            inline_cell_dom_id,
            partial: "people/inline_edit_cell",
            locals: {
              person: @person,
              field: inline_field,
              editing: true,
              error: @person.errors.full_messages.to_sentence
            }
          ), status: :unprocessable_entity
        end
        format.html { redirect_to people_path, alert: @person.errors.full_messages.to_sentence }
      end
    end
  end

  def inline_person_params
    raw = params.require(:person).permit(:company_id, :owner_id)

    case inline_field
    when "company_id"
      company_id = raw[:company_id]
      raise ActiveRecord::RecordNotFound if company_id.blank?

      company = current_workspace.companies.find(company_id)
      {company_id: company.id}
    when "owner_id"
      owner_id = raw[:owner_id]
      return {owner_id: nil} if owner_id.blank?

      owner = current_workspace.users.find(owner_id)
      {owner_id: owner.id}
    else
      raise ActionController::ParameterMissing, :inline_edit
    end
  end
end
