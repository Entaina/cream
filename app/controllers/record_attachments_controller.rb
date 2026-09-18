class RecordAttachmentsController < ApplicationController
  include RequiresFeature

  requires_feature :attachments
  def create
    attachable = find_attachable
    @attachment = attachable.record_attachments.new(attachment_params.merge(workspace: current_workspace, user: current_user))
    authorize @attachment

    if @attachment.save
      redirect_back fallback_location: polymorphic_path(attachable), notice: t("flashes.record_attachments.uploaded")
    else
      redirect_back fallback_location: polymorphic_path(attachable), alert: @attachment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @attachment = policy_scope(current_workspace.record_attachments).find(params[:id])
    authorize @attachment
    attachable = @attachment.attachable
    @attachment.destroy
    redirect_back fallback_location: polymorphic_path(attachable), notice: t("flashes.record_attachments.removed"), status: :see_other
  end

  private

  def attachment_params
    params.require(:record_attachment).permit(:file, :name)
  end

  def find_attachable
    klass = params.require(:attachable_type)
    raise ActionController::BadRequest unless RecordAttachment::ATTACHABLE_TYPES.include?(klass)

    klass.constantize.merge(policy_scope(current_workspace.public_send(klass.tableize))).find(params.require(:attachable_id))
  end
end
