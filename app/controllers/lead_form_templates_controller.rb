class LeadFormTemplatesController < ApplicationController
  include RequiresFeature
  requires_feature :lead_forms
  before_action :set_template, only: %i[edit update destroy preview]

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
    load_preview_products
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

  def preview
    authorize @template, :preview?

    unless @template.previewable?
      redirect_to lead_form_templates_path, alert: "Solo las páginas completas admiten vista previa."
      return
    end

    @preview_draft = preview_body_param.present?
    @preview_product = resolved_preview_product
    load_preview_products
    @lead_form_page_html = LeadFormTemplates::PagePreview.render(
      template: @template,
      view_context: LeadFormTemplates::PreviewViewContext.new(view_context),
      body: preview_body_param,
      product_id: @preview_product&.id
    )
    render :preview, layout: "public_lead_form"
  rescue Liquid::SyntaxError, Liquid::FileSystemError => e
    render plain: "No se pudo renderizar la plantilla: #{e.message}", status: :unprocessable_entity
  end

  private

  def set_template
    @template = policy_scope(current_workspace.lead_form_templates).find(params[:id])
  end

  def template_params
    params.require(:lead_form_template).permit(:slug, :partial, :body, :kind, :page_slug)
  end

  def preview_body_param
    params.dig(:lead_form_template, :body).presence
  end

  def load_preview_products
    @preview_products = current_workspace.products.ordered
  end

  def resolved_preview_product
    id = params[:preview_product_id].presence
    return if id.blank?

    current_workspace.products.find_by(id: id)
  end
end
