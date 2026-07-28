class RecordEmailsController < ApplicationController
  include RequiresFeature
  requires_feature :record_email
  def create
    record = find_record
    @message = current_workspace.email_messages.new(email_params.merge(user: current_user, record: record))
    scheduled_at = parse_scheduled_at
    @message.scheduled_at = scheduled_at
    @message.status = "scheduled" if scheduled_at
    @message.follow_up_at = follow_up_at_for(scheduled_at)
    authorize @message
    attach_record_files(record)
    attach_template_files

    if @message.save
      schedule_follow_up
      deliver_or_schedule(scheduled_at)
    else
      redirect_back fallback_location: polymorphic_path(record), alert: @message.errors.full_messages.to_sentence
    end
  end

  def destroy
    @message = policy_scope(current_workspace.email_messages).find(params[:id])
    authorize @message
    @message.destroy if @message.scheduled?
    redirect_back fallback_location: polymorphic_path(@message.record), notice: "Scheduled email cancelled."
  end

  def mark_replied
    @message = policy_scope(current_workspace.email_messages).find(params[:id])
    authorize @message, :update?
    @message.update!(replied_at: Time.current)
    redirect_back fallback_location: polymorphic_path(@message.record), notice: "Marked as replied; follow-up reminder cleared."
  end

  private

  def deliver_or_schedule(scheduled_at)
    if scheduled_at
      SendScheduledEmailJob.set(wait_until: scheduled_at).perform_later(@message.id)
      notice = "Email scheduled for #{format_time(scheduled_at)}."
    elsif @message.route_via_gmail?
      SendViaGmailJob.perform_later(@message.id)
      notice = "Email sent via Gmail."
    else
      RecordMailer.tracked_email(message: @message).deliver_later
      @message.track_sent!
      notice = "Email sent."
    end
    notice += " Follow-up reminder set for #{format_time(@message.follow_up_at)}." if @message.follow_up_at
    redirect_back fallback_location: polymorphic_path(@message.record), notice: notice
  end

  def schedule_follow_up
    return if @message.follow_up_at.blank?

    EmailFollowUpJob.set(wait_until: @message.follow_up_at).perform_later(@message.id)
  end

  # Follow-up is counted from when the email actually goes out (now, or the
  # scheduled time). Zero/blank means no reminder.
  def follow_up_at_for(scheduled_at)
    days = params[:follow_up_days].to_i
    return if days <= 0

    (scheduled_at || Time.current) + days.days
  end

  def format_time(time) = time.strftime("%-d %b %H:%M")

  def email_params
    params.require(:email_message).permit(:to_address, :subject, :body, attachments: [])
  end

  def attach_record_files(record)
    ids = Array(params[:record_attachment_ids]).map(&:presence).compact
    return if ids.empty?

    record.record_attachments.where(id: ids).includes(file_attachment: :blob).find_each do |attachment|
      @message.attachments.attach(attachment.file.blob)
    end
  end

  def attach_template_files
    return if params[:email_template_id].blank?

    template = current_workspace.email_templates.visible_to(current_user)
      .find_by(id: params[:email_template_id])
    return unless template

    ids = Array(params[:email_template_attachment_ids]).map(&:presence).compact
    return if ids.empty?

    template.attachments.where(id: ids).find_each do |file|
      @message.attachments.attach(file.blob)
    end
  end

  # Reads the optional "Send later" datetime. Blank or past values fall back to
  # sending immediately.
  def parse_scheduled_at
    raw = params[:scheduled_at]
    return if raw.blank?

    time = Time.zone.parse(raw.to_s)
    time if time&.future?
  rescue ArgumentError
    nil
  end

  def find_record
    klass = params.require(:record_type)
    raise ActionController::BadRequest unless EmailMessage::RECORD_TYPES.include?(klass)

    klass.constantize.merge(policy_scope(current_workspace.public_send(klass.tableize))).find(params.require(:record_id))
  end
end
