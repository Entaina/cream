class TasksController < ApplicationController
  include Filterable

  remembers_list_filters only: :index
  before_action :set_task, only: %i[update destroy toggle]

  def index
    scope = policy_scope(current_workspace.tasks).includes(:assignee, :taskable)
    @filter = params[:filter].presence_in(%w[pending completed all]) || "pending"
    @tasks = case @filter
    when "completed" then scope.completed.order(completed_at: :desc)
    when "all" then scope.due_order
    else scope.pending.due_order
    end
  end

  def create
    @task = current_workspace.tasks.new(task_params)
    @task.user = current_user
    @task.assignee ||= current_user
    set_taskable
    authorize @task

    if @task.save
      redirect_back fallback_location: tasks_path, notice: "Task created."
    else
      redirect_back fallback_location: tasks_path, alert: "Task needs a title."
    end
  end

  def update
    authorize @task
    @task.update(task_params)
    redirect_back fallback_location: tasks_path, notice: "Task updated."
  end

  def toggle
    authorize @task, :toggle?
    was_pending = !@task.completed?
    @task.toggle_completed!
    taskable = @task.taskable
    if was_pending && @task.completed? && taskable && taskable.tasks.pending.none?
      flash[:next_task_prompt] = {
        "type" => @task.taskable_type,
        "id" => @task.taskable_id,
        "name" => (taskable.try(:name) || taskable.try(:title)).to_s
      }
    end
    redirect_back fallback_location: tasks_path, status: :see_other
  end

  def destroy
    authorize @task
    @task.destroy
    redirect_back fallback_location: tasks_path, notice: "Task deleted.", status: :see_other
  end

  private

  def set_task
    @task = policy_scope(current_workspace.tasks).find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :due_on, :assignee_id)
  end

  def set_taskable
    return if params[:taskable_type].blank?
    raise ActionController::BadRequest unless %w[Company Person Deal].include?(params[:taskable_type])

    scope = current_workspace.public_send(params[:taskable_type].tableize)
    @task.taskable = policy_scope(scope).find(params[:taskable_id])
  end
end
