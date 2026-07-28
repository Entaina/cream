class CommentsController < ApplicationController
  include RequiresFeature
  requires_feature :comments
  def create
    commentable = find_commentable
    @comment = commentable.comments.new(comment_params.merge(workspace: current_workspace, user: current_user))
    authorize @comment

    if @comment.save
      if CreamFeatures.enabled?(:webhooks)
        WebhookDispatcher.dispatch(
          workspace: current_workspace,
          event: "comment.created",
          payload: { comment_id: @comment.id, record_type: commentable.class.name, record_id: commentable.id }
        )
      end
      redirect_to polymorphic_path(commentable), notice: "Comment added."
    else
      redirect_to polymorphic_path(commentable), alert: "Comment can't be empty."
    end
  end

  def destroy
    @comment = policy_scope(current_workspace.comments).find(params[:id])
    authorize @comment
    commentable = @comment.commentable
    @comment.destroy
    redirect_back fallback_location: polymorphic_path(commentable), notice: "Comment deleted.", status: :see_other
  end

  private

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def find_commentable
    klass = params.require(:commentable_type)
    raise ActionController::BadRequest unless Comment::COMMENTABLE_TYPES.include?(klass)

    klass.constantize.merge(policy_scope(current_workspace.public_send(klass.tableize))).find(params.require(:commentable_id))
  end
end
