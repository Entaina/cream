# Routes Action Mailer through the workspace Mailjet account when transactional
# sending is enabled. Campaigns still use the Send API (`MailjetAdapter`).
class MailjetDeliveryInterceptor
  HEADER = "X-Cream-Workspace-Id"
  SENDER_HEADER = "X-Cream-Sender-Email"
  SMTP_ADDRESS = "in-v3.mailjet.com"
  SMTP_PORT = 587

  def self.delivering_email(mail)
    sender_email = extract_sender_email!(mail)
    workspace_id = extract_workspace_id!(mail)
    return if skip_delivery_override?
    return if workspace_id.blank?

    connection = MailjetConnection.find_by(workspace_id: workspace_id)
    return unless connection&.transactional?

    apply_from!(mail, connection, sender_email: sender_email)
    mail.delivery_method(:smtp, smtp_settings(connection))
  end

  def self.skip_delivery_override?
    ActionMailer::Base.delivery_method == :test
  end
  private_class_method :skip_delivery_override?

  def self.extract_workspace_id!(mail)
    extract_internal_header!(mail, HEADER)
  end
  private_class_method :extract_workspace_id!

  def self.extract_sender_email!(mail)
    extract_internal_header!(mail, SENDER_HEADER)
  end
  private_class_method :extract_sender_email!

  def self.extract_internal_header!(mail, name)
    field = mail[name]
    return if field.blank?

    value = field.value
    mail.header.fields.delete_if { |item| item.name.to_s.casecmp?(name) }
    value
  end
  private_class_method :extract_internal_header!

  def self.apply_from!(mail, connection, sender_email: nil)
    original = Array(mail.from).first

    if sender_email.present?
      if connection.sender_domain_validated? && same_domain?(sender_email, connection.from_email)
        return
      end

      display_name = mail[:from].display_names&.first.presence || extract_display_name(original)
      mail.from = if display_name.present?
        "#{display_name} <#{connection.from_email}>"
      else
        formatted_from(connection)
      end
      mail.reply_to = sender_email
      return
    end

    mail.from = formatted_from(connection)
    return if original.blank? || extract_email(original).to_s.downcase == connection.from_email.to_s.downcase

    mail.reply_to ||= extract_email(original) || original
  end
  private_class_method :apply_from!

  def self.same_domain?(address, from_email)
    domain_for(address) == domain_for(from_email) && domain_for(address).present?
  end
  private_class_method :same_domain?

  def self.domain_for(address)
    extract_email(address.to_s).split("@", 2).last&.downcase
  end
  private_class_method :domain_for

  def self.extract_email(from_value)
    value = from_value.to_s.strip
    if value =~ /<([^>]+)>/
      ::Regexp.last_match(1).strip
    else
      value
    end
  end
  private_class_method :extract_email

  def self.extract_display_name(from_value)
    value = from_value.to_s.strip
    return if value.blank?

    if value =~ /\A(.+?)\s*<[^>]+>\z/
      ::Regexp.last_match(1).strip.delete('"')
    end
  end
  private_class_method :extract_display_name

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
