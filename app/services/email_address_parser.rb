# Parses RFC5322-style contact strings such as "Sol Fernandez <sol@example.com>".
class EmailAddressParser
  Parsed = Data.define(:email, :first_name, :last_name) do
    def name
      [ first_name, last_name ].compact_blank.join(" ").presence
    end
  end

  def self.extract(raw)
    parse(raw)&.email
  end

  def self.extract_all(raw)
    return [] if raw.blank?

    raw.to_s.split(/[,;]/).filter_map { |part| extract(part) }.uniq
  end

  def self.parse(raw)
    return nil if raw.blank?

    segment = raw.to_s.strip.gsub(/[,;]+\z/, "").strip
    return nil if segment.blank?

    email = nil
    display_name = nil

    if (match = segment.match(/\A(.+?)<([^>]+)>\z/m))
      display_name = unquote_name(match[1])
      email = match[2].strip.downcase
    elsif segment.match?(URI::MailTo::EMAIL_REGEXP)
      email = segment.downcase
    else
      email = segment.downcase
    end

    return nil unless email.match?(URI::MailTo::EMAIL_REGEXP)

    first_name, last_name = split_display_name(display_name)
    Parsed.new(email: email, first_name: first_name, last_name: last_name)
  end

  def self.apply_name_to_record!(record, parsed, first_name_attr: :first_name, last_name_attr: :last_name)
    return if parsed.nil?

    first_blank = record.public_send(first_name_attr).blank?
    last_blank = record.public_send(last_name_attr).blank?
    return unless first_blank && last_blank

    record.public_send("#{first_name_attr}=", parsed.first_name) if parsed.first_name.present?
    record.public_send("#{last_name_attr}=", parsed.last_name) if parsed.last_name.present?
  end

  def self.unquote_name(value)
    name = value.to_s.strip
    name = name.delete_prefix('"').delete_suffix('"').strip if name.start_with?('"') && name.end_with?('"')
    name.presence
  end
  private_class_method :unquote_name

  def self.split_display_name(display_name)
    return [ nil, nil ] if display_name.blank?

    parts = display_name.strip.split(/\s+/, 2)
    [ parts[0].presence, parts[1].to_s.presence ]
  end
  private_class_method :split_display_name
end
