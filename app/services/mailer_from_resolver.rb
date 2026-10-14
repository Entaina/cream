class MailerFromResolver
  def self.default_from_address
    from = Array(ActionMailer::Base.default[:from]).first.to_s.strip
    extract_email(from)
  end

  def self.portal_from(workspace)
    name = workspace.mail_from_name.to_s.strip.presence
    return if name.blank?

    email = default_from_address
    return if email.blank?

    formatted_display(name, email)
  end

  def self.formatted_display(name, email)
    Mail::Address.new.tap do |address|
      address.address = email
      address.display_name = name
    end.format
  end

  def self.extract_email(from_value)
    value = from_value.to_s.strip
    if value =~ /<([^>]+)>/
      ::Regexp.last_match(1).strip
    else
      value.presence
    end
  end
end
