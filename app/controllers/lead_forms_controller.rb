class LeadFormsController < ApplicationController
  include RequiresFeature
  requires_feature :lead_forms
  before_action :set_lead_form, only: %i[edit update destroy]

  def index
    @lead_forms = policy_scope(current_workspace.lead_forms).ordered.includes(:pipeline, :responsible, :email_template)
    authorize LeadForm
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
    @pipelines = current_workspace.pipelines.ordered.includes(:pipeline_stages)
    @responsibles = current_workspace.users.order(:name)
    @email_templates = current_workspace.email_templates.visible_to(current_user).ordered
    @template_keys = LeadForm.available_template_keys
  end

  def lead_form_params
    params.require(:lead_form).permit(
      :name, :slug, :template_key, :pipeline_id, :pipeline_stage_id, :responsible_id,
      :email_template_id, :collects_company, :active, :success_redirect_url,
      :hidden_field_keys_text,
      pipeline_routes: LeadForm::CONTACTO_HELP_TYPE_KEYS
    )
  end
end
