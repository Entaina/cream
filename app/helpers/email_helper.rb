module EmailHelper
  ALLOWED_EMAIL_BODY_TAGS = %w[p br strong em b i u s a ul ol li span blockquote h1 h2 h3].freeze
  ALLOWED_EMAIL_BODY_ATTRIBUTES = %w[href style].freeze

  def email_body_html(text)
    return "" if text.blank?

    if text.match?(/<\s*\w+/i)
      sanitize(text, tags: ALLOWED_EMAIL_BODY_TAGS, attributes: ALLOWED_EMAIL_BODY_ATTRIBUTES)
    else
      simple_format(text)
    end
  end

  def email_body_preview(text, length: 90)
    truncate(strip_tags(email_body_html(text)), length: length)
  end
end
