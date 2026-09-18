class CompaniesController < ApplicationController
  include ViewScoped
  include Filterable

  remembers_list_filters only: :index

  before_action :set_company, only: %i[show edit update destroy merge]
  before_action :set_edit_section, only: %i[edit update]

  SORTABLE = %w[name domain industry employee_range location created_at].freeze

  def index
    load_saved_views("Company")
    @companies = policy_scope(current_workspace.companies).includes(:owner, :people, custom_field_values: :custom_field)
    @companies = @companies.search(filter_value(:q))
    @companies = ListFilters.apply_industry(@companies, filter_value(:industry)) if filter_value(:industry).present?
    @companies = ListFilters.apply_owner(@companies, filter_value(:owner_id)) if filter_value(:owner_id).present?
    @companies = ListFilters.apply_created_at(@companies, @effective_filters)
    @companies = @companies.merge(Company.apply_custom_field_filters(current_workspace, filter_value(:cf)))
    @companies = apply_sorting(@companies, sortable: SORTABLE, default_column: "name")
    @pagy, @companies = pagy(:offset, @companies)
    @industries = current_workspace.companies.distinct.where.not(industry: [nil, ""]).order(:industry).pluck(:industry)
    @owners = current_workspace.users.order(:name)
    @custom_fields = current_workspace.custom_fields.where(record_type: "Company").ordered
    @duplicate_group_count = CompanyDuplicateGroups.call(current_workspace).size
  end

  # JSON search behind record pickers when the workspace has too many companies
  # to embed inline (see RecordPickerComponent::INLINE_LIMIT).
  def picker
    authorize Company, :index?
    companies = policy_scope(current_workspace.companies)
      .search(params[:q])
      .order(:name)
      .limit(10)
    render json: companies.map { |company|
      {id: company.id, name: company.name, hint: company.domain}
    }
  end

  def show
    authorize @company
    @deals = policy_scope(current_workspace.deals)
      .where(company_id: @company.id)
      .includes(:pipeline_stage, :products)
      .order(created_at: :desc)
    @people = @company.people.order(:first_name, :last_name)
    @company_tab = params[:tab].presence_in(%w[activity people deals information files]) || "activity"
    @company_tab = "activity" if @company_tab == "files" && !CreamFeatures.enabled?(:attachments)
    @pending_tasks = @company.tasks.pending.includes(:assignee).due_order
    @completed_tasks = @company.tasks.completed.includes(:assignee).order(completed_at: :desc)
    @activity_feed = RecordActivityFeed.new(@company, filter: params[:activity_filter], page: params[:activity_page],
      emails: CreamFeatures.enabled?(:record_email), comments: CreamFeatures.enabled?(:comments))
    @okm_chat_record = @company
    @note = Note.new
    @comment = Comment.new
    @email_message = EmailMessage.new
    @task = Task.new(due_on: Task.default_due_on)
  end

  def new
    @company = current_workspace.companies.new
    authorize @company
  end

  def create
    @company = current_workspace.companies.new(company_params)
    authorize @company
    @company.owner ||= current_user

    if @company.save
      respond_to do |format|
        format.html { redirect_to @company, notice: t("flashes.companies.created") }
        format.json { render json: {id: @company.id, name: @company.name}, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: {errors: @company.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @company
  end

  def update
    authorize @company
    if @company.update(company_params)
      redirect_to @edit_section ? company_path(@company, tab: "information") : @company, notice: t("flashes.companies.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @company
    @company.destroy
    redirect_to companies_path, notice: t("flashes.companies.deleted"), status: :see_other
  end

  def duplicates
    authorize Company, :index?
    @groups = CompanyDuplicateGroups.call(current_workspace)
  end

  def merge
    authorize @company, :merge?
    load_merge_candidates

    if request.post?
      @selected_secondary_ids = merge_params[:secondary_ids].to_a.map(&:to_i).uniq - [@company.id]
      secondaries = @merge_candidates.select { |candidate| @selected_secondary_ids.include?(candidate.id) }

      if secondaries.empty?
        flash.now[:alert] = "Select at least one company to merge."
        return render :merge, status: :unprocessable_entity
      end

      CompanyMerger.call(primary: @company, secondaries: secondaries, user: current_user)
      redirect_to @company, notice: t("flashes.companies.merged", count: secondaries.size, name: @company.name), status: :see_other
    else
      @selected_secondary_ids = Array(params[:secondary_ids]).map(&:to_i).uniq - [@company.id]
    end
  rescue CompanyMerger::Error => e
    flash.now[:alert] = e.message
    render :merge, status: :unprocessable_entity
  end

  private

  def set_edit_section
    @edit_section = params[:section].presence_in(%w[profile about fiscal management custom])
  end

  def set_company
    @company = policy_scope(current_workspace.companies).find(params[:id])
  end

  def load_merge_candidates
    duplicate_groups = CompanyDuplicateGroups.call(current_workspace)
      .select { |group| group.companies.any? { |company| company.id == @company.id } }

    candidate_ids = duplicate_groups.flat_map(&:companies).map(&:id).uniq - [@company.id]
    @merge_candidates = policy_scope(current_workspace.companies)
      .where(id: candidate_ids)
      .includes(:owner, :people, :deals)
      .order(:name, :id)
  end

  def merge_params
    params.permit(secondary_ids: [])
  end

  def company_params
    params.require(:company).permit(:name, :domain, :description, :industry, :employee_range,
      :location, :linkedin_url, :twitter_url, :annual_revenue, :owner_id, :fiscal_information, custom_fields: {})
  end
end
