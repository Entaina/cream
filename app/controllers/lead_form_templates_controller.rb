class LeadFormTemplatesController < ApplicationController
  include RequiresFeature
  requires_feature :lead_forms
  before_action :set_template, only: %i[edit update destroy]

  def index
    @kind = params[:kind].presence_in(%w[partial view]) || "all"
    scope = policy_scope(current_workspace.lead_form_templates).ordered
    scope = scope.partials if @kind == "partial"
    scope = scope.views if @kind == "view"
    @templates = scope
    authorize LeadFormTemplate
  end

  def new
    @template = current_workspace.lead_form_templates.new(partial: true)
    authorize @template
  end

  def create
    @template = current_workspace.lead_form_templates.new(template_params)
    authorize @template

    if @template.save
      redirect_to lead_form_templates_path, notice: "Plantilla creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @template
  end

  def update
    authorize @template
    if @template.update(template_params)
      redirect_to lead_form_templates_path, notice: "Plantilla actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @template
    @template.destroy
    redirect_to lead_form_templates_path, notice: "Plantilla eliminada.", status: :see_other
  end

  private

  def set_template
    @template = policy_scope(current_workspace.lead_form_templates).find(params[:id])
  end

  def template_params
    params.require(:lead_form_template).permit(:slug, :partial, :body)
  end
end
