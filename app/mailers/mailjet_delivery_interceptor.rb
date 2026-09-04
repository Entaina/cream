# Routes Action Mailer through the workspace Mailjet account when transactional
# sending is enabled. Campaigns still use the Send API (`MailjetAdapter`).
class MailjetDeliveryInterceptor
  HEADER = "X-Cream-Workspace-Id"
  SMTP_ADDRESS = "in-v3.mailjet.com"
  SMTP_PORT = 587

  def self.delivering_email(mail)
    workspace_id = extract_workspace_id!(mail)
    return if skip_delivery_override?
    return if workspace_id.blank?

    connection = MailjetConnection.find_by(workspace_id: workspace_id)
    return unless connection&.transactional?

    apply_from!(mail, connection)
    mail.delivery_method(:smtp, smtp_settings(connection))
  end

  def self.skip_delivery_override?
    ActionMailer::Base.delivery_method == :test
  end
  private_class_method :skip_delivery_override?

  def self.extract_workspace_id!(mail)
    field = mail[HEADER]
    return if field.blank?

    workspace_id = field.value
    mail.header.fields.delete_if { |item| item.name.to_s.casecmp?(HEADER) }
    workspace_id
  end
  private_class_method :extract_workspace_id!

  def self.apply_from!(mail, connection)
    original = Array(mail.from).first
    mail.from = formatted_from(connection)
    return if original.blank? || original.to_s.downcase == connection.from_email.to_s.downcase

    mail.reply_to ||= original
  end
  private_class_method :apply_from!

  def self.formatted_from(connection)
    if connection.from_name.present?
      "#{connection.from_name} <#{connection.from_email}>"
    else
      connection.from_email
    end
  end
  private_class_method :formatted_from

  def self.smtp_settings(connection)
    {
      address: SMTP_ADDRESS,
      port: SMTP_PORT,
      user_name: connection.api_key,
      password: connection.secret_key,
      domain: connection.from_email.to_s.split("@").last.presence || "mailjet.com",
      authentication: :plain,
      enable_starttls_auto: true
    }
  end
  private_class_method :smtp_settings
end
