class EmailLayoutsController < ApplicationController
  include RequiresFeature
  include EmailPreviewActions
  requires_feature :email_templates
  before_action :set_layout, only: %i[edit update destroy]

  def preview
    authorize EmailLayout, :preview?

    _subject, body = EmailTemplatePreview.render_layout(
      body: params[:body],
      sample_content: params[:sample_content],
      extra_tokens: preview_tokens_param
    )
    render_email_preview_result("Layout", body)
  end

  def index
    @layouts = policy_scope(current_workspace.email_layouts).ordered
    authorize EmailLayout
  end

  def new
    @layout = current_workspace.email_layouts.new(body: default_layout_body)
    authorize @layout
    @preview_tokens = preview_token_names(@layout)
  end

  def create
    @layout = current_workspace.email_layouts.new(layout_params)
    authorize @layout

    if @layout.save
      redirect_to email_templates_path, notice: "Layout creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @layout
    @preview_tokens = preview_token_names(@layout)
  end

  def update
    authorize @layout

    if @layout.update(layout_params)
      redirect_to email_templates_path, notice: "Layout actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @layout
    @layout.destroy
    redirect_to email_templates_path, notice: "Layout eliminado.", status: :see_other
  end

  private

  def set_layout
    @layout = policy_scope(current_workspace.email_layouts).find(params[:id])
  end

  def layout_params
    params.require(:email_layout).permit(:name, :body)
  end

  def preview_token_names(layout)
    (EmailTemplatePreview::STANDARD_TOKENS + EmailTemplatePreview.extract_tokens(layout.body)).uniq.sort
  end

  def default_layout_body
    <<~HTML.strip
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Email</title>
      </head>
      <body>
        {{ content }}
      </body>
      </html>
    HTML
  end
end
