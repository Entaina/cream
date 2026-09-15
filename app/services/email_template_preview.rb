class EmailTemplatePreview
  STANDARD_TOKENS = %w[first_name last_name name company email].freeze
  SAMPLE_DEFAULTS = {
    "first_name" => "María",
    "last_name" => "García",
    "name" => "María García",
    "company" => "Acme Corp",
    "email" => "maria@example.com"
  }.freeze
  SAMPLE_CONTENT = <<~HTML.strip
    <p>Hola {first_name},</p>
    <p>Este es un ejemplo del contenido que irá dentro del layout.</p>
  HTML

  def self.extract_tokens(*texts)
    tokens = Set.new
    texts.compact.each do |text|
      text.to_s.scan(/\{(\w+)\}/) { tokens << Regexp.last_match(1) }
      text.to_s.scan(/\{\{\s*(\w+)\s*\}\}/) do
        token = Regexp.last_match(1)
        tokens << token unless token == "content"
      end
    end
    tokens.delete("content")
    tokens.sort
  end

  def self.merge_tokens(extra_tokens)
    SAMPLE_DEFAULTS.merge(extra_tokens.stringify_keys.transform_values { |value| value.to_s.strip.presence }.compact)
  end

  def self.render_template(subject:, body:, layout: nil, extra_tokens: {})
    record = EmailPreviewRecord.new(merge_tokens(extra_tokens))
    template = EmailTemplate.new(body: body.to_s, subject: subject.to_s, email_layout: layout)
    [
      template.render_subject_for(record, extra_tokens: merge_tokens(extra_tokens)),
      template.render_for(record, extra_tokens: merge_tokens(extra_tokens))
    ]
  end

  def self.render_layout(body:, sample_content: SAMPLE_CONTENT, extra_tokens: {})
    layout = EmailLayout.new(body: body.to_s)
    record = EmailPreviewRecord.new(merge_tokens(extra_tokens))
    merged = merge_tokens(extra_tokens)
    rendered_sample = EmailTemplate.interpolate_string(sample_content, record, merged)
    if sample_content.include?("{%") || sample_content.include?("{{")
      rendered_sample = Marketing::LiquidRenderer.render(sample_content, record: record, extra_tokens: merged)
    end
    [
      "Layout: #{layout.name || "Vista previa"}",
      layout.render_with(rendered_sample, record: record, extra_tokens: merged)
    ]
  end

  def self.render_email(subject:, body:, extra_tokens: {})
    merged = merge_tokens(extra_tokens)
    record = EmailPreviewRecord.new(merged)
    template = EmailTemplate.new(subject: subject.to_s, body: body.to_s)
    [
      template.render_subject_for(record, extra_tokens: merged),
      template.render_string(body.to_s, record, merged)
    ]
  end
end
