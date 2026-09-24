module EmailHelper
  ALLOWED_EMAIL_BODY_TAGS = %w[
    p br strong em b i u s a ul ol li span blockquote h1 h2 h3 h4
    div table thead tbody tr th td img center hr pre code
  ].freeze
  IFRAME_EMAIL_BODY_TAGS = (ALLOWED_EMAIL_BODY_TAGS + %w[style]).freeze
  ALLOWED_EMAIL_BODY_ATTRIBUTES = %w[href style src alt width height border cellpadding cellspacing align valign class id target].freeze
  FULL_HTML_DOCUMENT_PATTERN = /<!DOCTYPE|<\s*html\b/i
  HTML_MARKUP_PATTERN = /<\/?[a-z][\w:-]*\b/i
  BLOCK_MARKUP_PATTERN = /<(?:p|div|br|table|tr|li|h[1-6]|blockquote|pre|ul|ol|html|body)\b/i
  EMAIL_FRAME_STYLES = <<~CSS.freeze
    body { margin: 0; font: 14px/1.55 Lato, ui-sans-serif, sans-serif; color: #31363b; overflow-wrap: anywhere; }
    p, ul, ol, blockquote, pre, h1, h2, h3, h4 { margin: 0.75em 0; }
    ul, ol { padding-inline-start: 1.25rem; }
    img { max-width: 100%; height: auto; }
    table { max-width: 100%; border-collapse: collapse; }
    pre, code { white-space: pre-wrap; }
    a { color: #5c748c; }
  CSS

  def email_body_html(text)
    return "" if text.blank?

    if full_html_document?(text)
      sanitize_email_document(text)
    elsif html_markup?(text)
      sanitize(preserve_text_newlines(text), tags: ALLOWED_EMAIL_BODY_TAGS, attributes: ALLOWED_EMAIL_BODY_ATTRIBUTES)
    else
      simple_format(text)
    end
  end

  # Isolated document for in-app display. Nil when the body is plain text.
  def email_body_srcdoc(text)
    return if text.blank?
    return unless html_markup?(text) || full_html_document?(text)

    if full_html_document?(text)
      ensure_blank_target(sanitize_email_document(text))
    else
      fragment = sanitize(preserve_text_newlines(text), tags: IFRAME_EMAIL_BODY_TAGS, attributes: ALLOWED_EMAIL_BODY_ATTRIBUTES)
      wrap_email_fragment(fragment)
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

  def html_markup?(text)
    text.to_s.match?(HTML_MARKUP_PATTERN)
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
      .gsub(/\s(?:href|src)\s*=\s*(['"])\s*javascript:[^'"]*\1/i, "")
  end

  def preserve_text_newlines(text)
    html = text.to_s.gsub(/\r\n?/, "\n")
    return html if html.match?(BLOCK_MARKUP_PATTERN)

    html.gsub("\n", "<br>")
  end

  def wrap_email_fragment(fragment)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
      <meta charset="utf-8">
      <base target="_blank">
      <style>#{EMAIL_FRAME_STYLES}</style>
      </head>
      <body>#{fragment}</body>
      </html>
    HTML
  end

  def ensure_blank_target(html)
    return html if html.match?(/<base\b/i)

    if html.match?(/<head\b[^>]*>/i)
      html.sub(/<head\b[^>]*>/i, "\\0<base target=\"_blank\">")
    else
      "<base target=\"_blank\">#{html}"
    end
  end
end
