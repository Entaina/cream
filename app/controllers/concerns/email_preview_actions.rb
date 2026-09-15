module EmailPreviewActions
  extend ActiveSupport::Concern

  private

  def render_email_preview_result(subject, body)
    @preview_subject = subject
    @preview_body = body
    render "email_previews/show", layout: "email_preview"
  rescue StandardError => e
    render plain: "No se pudo renderizar la vista previa: #{e.message}", status: :unprocessable_entity
  end

  def preview_tokens_param
    params.fetch(:preview_tokens, {}).permit!.to_h
  end
end
