class NotificationsController < ApplicationController
  include RequiresFeature

  requires_feature :notifications
  skip_after_action :verify_policy_scoped, only: :index

  def index
    NotificationService.check_overdue_tasks!(current_workspace)
    @notifications = policy_scope(Notification).recent_first.limit(50)
    authorize Notification
  end

  def update
    @notification = policy_scope(Notification).find(params[:id])
    authorize @notification
    @notification.mark_read!
    redirect_back fallback_location: notifications_path
  end

  def mark_all_read
    authorize Notification, :mark_all_read?
    policy_scope(Notification).unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "All notifications marked as read."
  end
end
