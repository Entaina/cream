class EmailTemplate < ApplicationRecord
  BODY_EDITORS = %w[quill html].freeze
  QUILL_SUPPORTED_TAGS = %w[p br strong b em i u s a ul ol li span].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :email_layout, optional: true

  has_many_attached :attachments

  validates :name, :body, presence: true
  validates :body_editor, inclusion: {in: BODY_EDITORS}
  validate :attachments_within_limits

  scope :visible_to, ->(user) {
    where(user: user).or(where(shared: true))
  }
  scope :ordered, -> { order(:name, :id) }

  def self.quill_unsupported_tags(html)
    return [] if html.blank?

    tags = html.to_s.scan(/<\/?([a-z][a-z0-9]*)\b/i).flatten.map(&:downcase).uniq
    tags.reject { |tag| QUILL_SUPPORTED_TAGS.include?(tag) }
  end

  def self.interpolate_string(text, record, extra_tokens = {})
    text.to_s.gsub(/\{(\w+)\}/) do
      token = Regexp.last_match(1)
      value = extra_tokens[token] || extra_tokens[token.to_sym]
      next value.to_s unless value.nil?

      template_value(record, token)
    end
  end

  def effective_body_editor
    return "html" if body_editor == "quill" && self.class.quill_unsupported_tags(body).any?

    body_editor
  end

  def picker_body
    email_layout ? email_layout.preview_body_for(body) : body
  end

  def picker_body_editor
    return "html" if email_layout || effective_body_editor == "html"
    return "html" if self.class.quill_unsupported_tags(picker_body).any?

    "quill"
  end

  def render_for(record, extra_tokens: {})
    wrap_with_layout(interpolate(render_body(record, extra_tokens), record, extra_tokens), record, extra_tokens)
  end

  def render_subject_for(record, extra_tokens: {})
    interpolate(render_subject(record, extra_tokens), record, extra_tokens)
  end

  def render_custom_for(record, subject: nil, body: nil, extra_tokens: {})
    rendered_subject = subject.present? ? render_string(subject, record, extra_tokens) : render_subject_for(record, extra_tokens:)
    rendered_body = if body.present?
      wrap_with_layout(render_string(body, record, extra_tokens), record, extra_tokens)
    else
      render_for(record, extra_tokens:)
    end
    [rendered_subject, rendered_body]
  end

  def render_string(text, record, extra_tokens = {})
    result = text.to_s
    if result.include?("{%") || result.include?("{{")
      result = Marketing::LiquidRenderer.render(result, record: record, extra_tokens: extra_tokens)
    end
    interpolate(result, record, extra_tokens)
  end

  def liquid?
    body.to_s.include?("{%") || body.to_s.include?("{{")
  end

  def self.template_value(record, token)
    case token
    when "first_name" then record.try(:first_name)
    when "last_name" then record.try(:last_name)
    when "name" then record.try(:display_name) || record.try(:name)
    when "company" then record.try(:company)&.name || record.try(:person)&.company&.name
    when "email" then record.try(:email)
    else "{#{token}}"
    end.to_s
  end
  private_class_method :template_value

  private

  def render_body(record, extra_tokens)
    text = body
    return text unless liquid?

    Marketing::LiquidRenderer.render(text, record: record, extra_tokens: extra_tokens)
  end

  def render_subject(record, extra_tokens)
    text = subject.to_s
    return text unless text.include?("{%") || text.include?("{{")

    Marketing::LiquidRenderer.render(text, record: record, extra_tokens: extra_tokens)
  end

  def interpolate(text, record, extra_tokens)
    self.class.interpolate_string(text, record, extra_tokens)
  end

  def wrap_with_layout(content_html, record, extra_tokens)
    return content_html unless email_layout

    email_layout.render_with(content_html, record: record, extra_tokens: extra_tokens)
  end

  def attachments_within_limits
    return unless attachments.attached?

    if attachments.count > EmailMessage::MAX_ATTACHMENTS
      errors.add(:attachments, :attachment_count_exceeded, count: EmailMessage::MAX_ATTACHMENTS)
      return
    end

    total = 0
    attachments.each do |file|
      if file.byte_size > EmailMessage::MAX_ATTACHMENT_SIZE
        errors.add(:attachments, :attachment_file_too_large, filename: file.filename, megabytes: EmailMessage::MAX_ATTACHMENT_SIZE / 1.megabyte)
      end
      total += file.byte_size
    end

    if total > EmailMessage::MAX_TOTAL_ATTACHMENT_SIZE
      errors.add(:attachments, :attachment_total_too_large, megabytes: EmailMessage::MAX_TOTAL_ATTACHMENT_SIZE / 1.megabyte)
    end
  end
end
