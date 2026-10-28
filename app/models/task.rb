class Task < ApplicationRecord
  include WorkspaceScopedAssociations

  def self.default_due_on = Date.current + 1.day

  belongs_to :workspace
  belongs_to :taskable, polymorphic: true, optional: true
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :user

  validates :title, presence: true
  validates_polymorphic_same_workspace :taskable, if: -> { taskable.present? }

  before_save :assign_from_mentions

  scope :pending, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :overdue, -> { where("due_on < ?", Date.current) }
  scope :due_today, -> { where(due_on: Date.current) }
  scope :due_today_or_overdue, -> { where("due_on IS NOT NULL AND due_on <= ?", Date.current) }
  scope :due_order, -> { order(Arel.sql("due_on ASC NULLS LAST"), :id) }
  scope :due_order_desc, -> { order(Arel.sql("due_on DESC NULLS LAST"), :id) }

  def completed? = completed_at.present?

  def toggle_completed!
    if completed?
      update!(completed_at: nil)
    else
      update!(completed_at: Time.current)
      taskable.track_activity("task_completed", metadata: {task_id: id, title: title}) if taskable.respond_to?(:track_activity)
      if CreamFeatures.enabled?(:webhooks)
        WebhookDispatcher.dispatch(workspace: workspace, event: "task.completed", payload: {task_id: id, title: title})
      end
      if CreamFeatures.enabled?(:automations) && taskable
        AutomationJob.perform_later("task.completed", taskable, {"title" => title})
      end
    end
  end

  def overdue? = !completed? && due_on.present? && due_on < Date.current

  private

  def assign_from_mentions
    return unless new_record? || will_save_change_to_title?

    mentioned = MentionParser.users_from(title, workspace: workspace).first
    self.assignee = mentioned if mentioned
  end
end
