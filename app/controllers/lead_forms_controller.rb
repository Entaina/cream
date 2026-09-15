class LeadFormsController < ApplicationController
  include RequiresFeature

  requires_feature :lead_forms
  before_action :set_lead_form, only: %i[show edit update destroy]

  def index
    @lead_forms = policy_scope(current_workspace.lead_forms).ordered.includes(:pipeline, :responsible, :email_template)
    authorize LeadForm
  end

  def show
    authorize @lead_form
    mql_submissions = @lead_form.lead_submissions.where(capture_destination: "mql").includes(:person)
    grouped = mql_submissions.group_by(&:person_id)
    @mql_people = grouped.map do |person_id, rows|
      person = rows.first.person
      {
        person: person,
        submission_count: rows.size,
        first_at: rows.map(&:created_at).min,
        last_at: rows.map(&:created_at).max,
        eligible: Marketing::MqlEligibility.eligible?(person, subscription_type_id: @lead_form.subscription_type_id)
      }
    end.sort_by { |row| row[:last_at] }.reverse

    @submissions = @lead_form.lead_submissions.includes(:person).order(created_at: :desc)
    @submissions_pagy, @submissions = pagy(:offset, @submissions, limit: 25)
  end

  def new
    @lead_form = current_workspace.lead_forms.new(active: true)
    authorize @lead_form
    load_form_options
  end

  def create
    @lead_form = current_workspace.lead_forms.new(lead_form_params)
    authorize @lead_form

    if @lead_form.save
      redirect_to lead_forms_path, notice: "Formulario creado."
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @lead_form
    load_form_options
  end

  def update
    authorize @lead_form
    if @lead_form.update(lead_form_params)
      redirect_to lead_forms_path, notice: "Formulario actualizado."
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @lead_form
    @lead_form.destroy
    redirect_to lead_forms_path, notice: "Formulario eliminado.", status: :see_other
  end

  private

  def set_lead_form
    @lead_form = policy_scope(current_workspace.lead_forms).find(params[:id])
  end

  def load_form_options
    SubscriptionType.ensure_defaults!(current_workspace)
    @pipelines = current_workspace.pipelines.ordered.includes(:pipeline_stages)
    @responsibles = current_workspace.users.order(:name)
    @email_templates = current_workspace.email_templates.visible_to(current_user).ordered
    @products = current_workspace.products.ordered
    @subscription_types = current_workspace.subscription_types.active.order(:name)
    @template_keys = LeadForm.available_template_keys(workspace: current_workspace)
  end

  def lead_form_params
    permitted = params.require(:lead_form).permit(
      :name, :slug, :template_key, :destination, :pipeline_id, :pipeline_stage_id, :responsible_id,
      :email_template_id, :product_id, :subscription_type_id, :marketing_consent_text,
      :collects_company, :active, :success_redirect_url,
      :hidden_field_keys_text, :first_task_title, :first_task_due_days,
      :pipeline_routes_submitted,
      pipeline_routes: {},
      pipeline_route_keys: [],
      pipeline_route_pipeline_ids: []
    )

    route_keys = permitted.delete(:pipeline_route_keys)
    route_pipeline_ids = permitted.delete(:pipeline_route_pipeline_ids)
    submitted = permitted.delete(:pipeline_routes_submitted)

    if submitted.present?
      permitted[:pipeline_routes] = LeadForm.build_pipeline_routes_from_form(route_keys, route_pipeline_ids)
    end

    permitted
  end
end
