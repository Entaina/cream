class EmailTemplatesController < ApplicationController
  include RequiresFeature
  include EmailPreviewActions
  requires_feature :email_templates
  before_action :set_template, only: %i[show edit update destroy]

  def show
    authorize @template
    render json: {
      id: @template.id,
      subject: @template.subject,
      body: @template.body,
      body_editor: @template.effective_body_editor,
      email_layout_id: @template.email_layout_id
    }
  end

  def preview
    authorize EmailTemplate, :preview?

    layout = preview_layout
    subject, body = EmailTemplatePreview.render_template(
      subject: params[:subject],
      body: params[:body],
      layout: layout,
      extra_tokens: preview_tokens_param
    )
    render_email_preview_result(subject, body)
  end

  def index
    @templates = policy_scope(current_workspace.email_templates).visible_to(current_user).ordered.includes(:email_layout, attachments_attachments: :blob)
    @layouts = policy_scope(current_workspace.email_layouts).ordered
    authorize EmailTemplate
  end

  def new
    @template = current_workspace.email_templates.new(user: current_user)
    authorize @template
    @preview_tokens = preview_token_names(@template)
  end

  def create
    @template = current_workspace.email_templates.new(template_params.merge(user: current_user))
    authorize @template

    if @template.save
      redirect_to email_templates_path, notice: "Plantilla creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @template
    @preview_tokens = preview_token_names(@template)
  end

  def update
    authorize @template
    purge_attachments

    attrs = template_params
    new_files = Array(attrs[:attachments]).compact_blank

    # Don't mass-assign attachments: empty file inputs delete existing ones in Rails 8,
    # and assigning new files replaces instead of appending.
    @template.assign_attributes(attrs.except(:attachments))
    @template.attachments.attach(new_files) if new_files.any?

    if @template.save
      redirect_to email_templates_path, notice: "Plantilla actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @template
    @template.destroy
    redirect_to email_templates_path, notice: "Plantilla eliminada.", status: :see_other
  end

  private

  def set_template
    @template = policy_scope(current_workspace.email_templates).find(params[:id])
  end

  def template_params
    params.require(:email_template).permit(:name, :subject, :body, :body_editor, :email_layout_id, :shared, attachments: [])
  end

  def purge_attachments
    ids = Array(params[:purge_attachment_ids]).map(&:presence).compact
    return if ids.empty?

    @template.attachments.where(id: ids).find_each(&:purge)
  end

  def preview_layout
    return if params[:email_layout_id].blank?

    policy_scope(current_workspace.email_layouts).find_by(id: params[:email_layout_id])
  end

  def preview_token_names(template)
    (EmailTemplatePreview::STANDARD_TOKENS + EmailTemplatePreview.extract_tokens(
      template.subject,
      template.body,
      template.email_layout&.body
    )).uniq.sort
  end
end
