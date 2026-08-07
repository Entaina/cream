class EmailTemplatesController < ApplicationController
  include RequiresFeature
  requires_feature :email_templates
  before_action :set_template, only: %i[edit update destroy]

  def index
    @templates = policy_scope(current_workspace.email_templates).visible_to(current_user).ordered.includes(attachments_attachments: :blob)
    authorize EmailTemplate
  end

  def new
    @template = current_workspace.email_templates.new(user: current_user)
    authorize @template
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
    params.require(:email_template).permit(:name, :subject, :body, :shared, attachments: [])
  end

  def purge_attachments
    ids = Array(params[:purge_attachment_ids]).map(&:presence).compact
    return if ids.empty?

    @template.attachments.where(id: ids).find_each(&:purge)
  end
end
