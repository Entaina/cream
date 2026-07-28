class MailMergeJob < ApplicationJob
  queue_as :default

  def perform(workspace_id, user_id, record_type, record_ids, subject, body, template_id = nil)
    workspace = Workspace.find(workspace_id)
    user = User.find(user_id)
    template = template_id && workspace.email_templates.find_by(id: template_id)
    batch_id = SecureRandom.uuid

    klass = record_type.constantize
    klass.where(workspace: workspace, id: record_ids).find_each do |record|
      to = record.try(:email) || record.try(:contacts)&.first&.email
      next unless to

      rendered_body = template ? template.render_for(record) : body
      rendered_subject = subject.gsub(/\{name\}/, record.display_name.to_s)

      message = workspace.email_messages.create!(
        user: user,
        record: record,
        to_address: to,
        subject: rendered_subject,
        body: rendered_body,
        mail_merge_batch_id: batch_id
      )

      attach_template_files(message, template)
      RecordMailer.tracked_email(message: message).deliver_now
    end
  end

  private

  def attach_template_files(message, template)
    return unless template&.attachments&.attached?

    template.attachments.each { |file| message.attachments.attach(file.blob) }
  end
end
