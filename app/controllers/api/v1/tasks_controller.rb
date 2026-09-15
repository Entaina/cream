module Api
  module V1
    class TasksController < BaseController
      def index
        tasks = policy_scope(current_workspace.tasks).includes(:assignee, :taskable)
        render json: tasks.map { |task| task_json(task) }
      end

      def show
        task = policy_scope(current_workspace.tasks).find(params[:id])
        authorize task
        render json: task_json(task)
      end

      def create
        task = current_workspace.tasks.new(task_params.except(:completed, :taskable_type, :taskable_id))
        task.user = current_user
        task.assignee ||= current_user
        set_taskable(task)
        apply_completed_on_create(task, task_params[:completed])
        authorize task

        if task.save
          render json: task_json(task), status: :created
        else
          render json: {errors: task.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def update
        task = policy_scope(current_workspace.tasks).find(params[:id])
        authorize task

        attrs = task_params.except(:completed, :taskable_type, :taskable_id)
        completed_flag = completed_param_provided? ? ActiveModel::Type::Boolean.new.cast(task_params[:completed]) : nil

        task.assign_attributes(attrs)
        set_taskable(task) if taskable_params_present?

        if task.save
          apply_completed_on_update(task, completed_flag) unless completed_flag.nil?
          render json: task_json(task.reload)
        else
          render json: {errors: task.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def destroy
        task = policy_scope(current_workspace.tasks).find(params[:id])
        authorize task
        task.destroy
        head :no_content
      end

      private

      def task_params
        params.require(:task).permit(:title, :due_on, :assignee_id, :taskable_type, :taskable_id, :completed)
      end

      def completed_param_provided?
        params[:task].key?(:completed) || params[:task].key?("completed")
      end

      def taskable_params_present?
        task_params[:taskable_type].present? || task_params[:taskable_id].present?
      end

      def set_taskable(task)
        return unless taskable_params_present?

        type = task_params[:taskable_type]
        id = task_params[:taskable_id]
        raise ActionController::BadRequest unless %w[Company Person Deal].include?(type)

        scope = current_workspace.public_send(type.tableize)
        task.taskable = policy_scope(scope).find(id)
      end

      def apply_completed_on_create(task, completed_flag)
        return unless completed_param_provided?

        task.completed_at = ActiveModel::Type::Boolean.new.cast(completed_flag) ? Time.current : nil
      end

      def apply_completed_on_update(task, completed_flag)
        return if completed_flag == task.completed?

        if completed_flag
          task.toggle_completed! if !task.completed?
        else
          task.update!(completed_at: nil)
        end
      end

      def task_json(task)
        {
          id: task.id,
          title: task.title,
          due_on: task.due_on&.iso8601,
          completed: task.completed?,
          completed_at: task.completed_at&.iso8601,
          assignee_id: task.assignee_id,
          taskable_type: task.taskable_type,
          taskable_id: task.taskable_id,
          created_at: task.created_at.iso8601,
          updated_at: task.updated_at.iso8601
        }
      end
    end
  end
end
