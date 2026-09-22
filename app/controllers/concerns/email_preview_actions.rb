module EmailPreviewActions
  extend ActiveSupport::Concern

  private

  def render_email_preview_result(subject, body)
    @preview_subject = subject
    @preview_body = body
    render "email_previews/show", layout: "email_preview"
  rescue => e
    render plain: t("flashes.email_templates.preview_failed", message: e.message), status: :unprocessable_entity
  end

  def preview_tokens_param
    allowed_keys = allowed_preview_token_keys
    params.fetch(:preview_tokens, ActionController::Parameters.new).permit(*allowed_keys).to_h
  end

  def allowed_preview_token_keys
    (
      EmailTemplatePreview::STANDARD_TOKENS +
      EmailTemplatePreview.extract_tokens(
        params[:subject],
        params[:body],
        params[:sample_content]
      )
    ).uniq
  end
end
