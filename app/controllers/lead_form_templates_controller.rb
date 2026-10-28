class LeadFormTemplatesController < ApplicationController
  include RequiresFeature

  requires_feature :lead_forms
  before_action :set_template, only: %i[edit update destroy preview]
  # The preview renders the template as published; see WorkspaceTemplateCsp.
  content_security_policy_report_only only: :preview

  def index
    @kind = params[:kind].presence_in(%w[partial view booking layout]) || "all"
    scope = policy_scope(current_workspace.lead_form_templates).ordered
    scope = scope.partials if @kind == "partial"
    scope = scope.views.where.not(kind: %w[booking layout]) if @kind == "view"
    scope = scope.booking_pages if @kind == "booking"
    scope = scope.public_layouts if @kind == "layout"
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
      redirect_to lead_form_templates_path, notice: t("flashes.lead_form_templates.created")
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
      redirect_to lead_form_templates_path, notice: t("flashes.lead_form_templates.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @template
    @template.destroy
    redirect_to lead_form_templates_path, notice: t("flashes.lead_form_templates.deleted"), status: :see_other
  end

  def preview
    authorize @template, :preview?

    unless @template.previewable?
      redirect_to lead_form_templates_path, alert: t("flashes.lead_form_templates.preview_pages_only")
      return
    end

    @preview_draft = preview_body_param.present?
    @preview_product = resolved_preview_product
    load_preview_products
    preview_view_context = LeadFormTemplates::PreviewViewContext.new(view_context)
    @lead_form_page_html = if @template.layout?
      render_layout_template_preview(preview_view_context)
    else
      LeadFormTemplates::PagePreview.render(
        template: @template,
        view_context: preview_view_context,
        body: preview_body_param,
        product_id: @preview_product&.id
      )
    end
    render :preview, layout: "public_lead_form"
  rescue Liquid::SyntaxError, Liquid::FileSystemError => e
    render plain: t("flashes.lead_form_templates.render_failed", message: e.message), status: :unprocessable_entity
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

  def render_layout_template_preview(preview_view_context)
    content_html = render_to_string(partial: "lead_form_templates/layout_preview_content")
    PublicLayoutTemplates::Renderer.render(
      template: layout_template_for_preview,
      content_html: content_html,
      workspace: current_workspace,
      view_context: preview_view_context
    )
  end

  def layout_template_for_preview
    return @template if preview_body_param.blank?

    @template.dup.tap { |copy| copy.body = preview_body_param }
  end
end
