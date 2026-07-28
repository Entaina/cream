class NotesController < ApplicationController
  def create
    notable = find_notable
    @note = notable.notes.new(note_params.merge(workspace: current_workspace, user: current_user))
    authorize @note

    if @note.save
      redirect_back fallback_location: polymorphic_path(notable), notice: "Note added."
    else
      redirect_back fallback_location: polymorphic_path(notable), alert: "Note can't be empty."
    end
  end

  def update
    @note = policy_scope(current_workspace.notes).find(params[:id])
    authorize @note
    @note.update(note_params)
    redirect_back fallback_location: polymorphic_path(@note.notable), notice: "Note updated."
  end

  def destroy
    @note = policy_scope(current_workspace.notes).find(params[:id])
    authorize @note
    notable = @note.notable
    @note.destroy
    redirect_back fallback_location: polymorphic_path(notable), notice: "Note deleted.", status: :see_other
  end

  private

  def note_params
    params.require(:note).permit(:title, :body)
  end

  def find_notable
    klass = params.require(:notable_type)
    raise ActionController::BadRequest unless %w[Company Person Deal].include?(klass)

    klass.constantize.merge(policy_scope(current_workspace.public_send(klass.tableize))).find(params.require(:notable_id))
  end
end
