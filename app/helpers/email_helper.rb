module EmailHelper
  ALLOWED_EMAIL_BODY_TAGS = %w[
    p br strong em b i u s a ul ol li span blockquote h1 h2 h3 h4
    div table thead tbody tr th td img center hr
  ].freeze
  ALLOWED_EMAIL_BODY_ATTRIBUTES = %w[href style src alt width height border cellpadding cellspacing align valign class id].freeze
  FULL_HTML_DOCUMENT_PATTERN = /<!DOCTYPE|<\s*html\b/i

  def email_body_html(text)
    return "" if text.blank?

    if full_html_document?(text)
      sanitize_email_document(text)
    elsif text.match?(/<\s*\w+/i)
      sanitize(text, tags: ALLOWED_EMAIL_BODY_TAGS, attributes: ALLOWED_EMAIL_BODY_ATTRIBUTES)
    else
      simple_format(text)
    end
  end

  def email_delivery_html(text)
    return "" if text.blank?

    if full_html_document?(text)
      sanitize_email_document(text)
    else
      email_body_html(text)
    end
  end

  def full_html_document?(text)
    text.to_s.match?(FULL_HTML_DOCUMENT_PATTERN)
  end

  def email_body_preview(text, length: 90)
    truncate(strip_tags(email_body_html(text)), length: length)
  end

  def insert_open_tracking_pixel(html, tracking_url)
    pixel = %(<img src="#{ERB::Util.html_escape(tracking_url)}" width="1" height="1" alt="" style="display:none">)
    if html.include?("</body>")
      html.sub("</body>", "#{pixel}</body>")
    else
      "#{html}#{pixel}"
    end
  end

  private

  def sanitize_email_document(text)
    text.to_s
      .gsub(/<script\b[^>]*>.*?<\/script>/im, "")
      .gsub(/\son\w+\s*=\s*(['"]).*?\1/i, "")
  end
end
