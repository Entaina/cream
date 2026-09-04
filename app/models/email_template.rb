class EmailTemplate < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  has_many_attached :attachments

  validates :name, :body, presence: true
  validate :attachments_within_limits

  scope :visible_to, ->(user) {
    where(user: user).or(where(shared: true))
  }
  scope :ordered, -> { order(:name, :id) }

  def render_for(record, extra_tokens: {})
    interpolate(render_body(record, extra_tokens), record, extra_tokens)
  end

  def render_subject_for(record, extra_tokens: {})
    interpolate(render_subject(record, extra_tokens), record, extra_tokens)
  end

  def render_custom_for(record, subject: nil, body: nil, extra_tokens: {})
    rendered_subject = subject.present? ? render_string(subject, record, extra_tokens) : render_subject_for(record, extra_tokens:)
    rendered_body = body.present? ? render_string(body, record, extra_tokens) : render_for(record, extra_tokens:)
    [ rendered_subject, rendered_body ]
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

  private

  def render_body(record, extra_tokens)
    return body unless liquid?

    Marketing::LiquidRenderer.render(body, record: record, extra_tokens: extra_tokens)
  end

  def render_subject(record, extra_tokens)
    text = subject.to_s
    return text unless text.include?("{%") || text.include?("{{")

    Marketing::LiquidRenderer.render(text, record: record, extra_tokens: extra_tokens)
  end

  def interpolate(text, record, extra_tokens)
    text.to_s.gsub(/\{(\w+)\}/) do
      token = Regexp.last_match(1)
      value = extra_tokens[token] || extra_tokens[token.to_sym]
      next value.to_s unless value.nil?

      template_value(record, token)
    end
  end

  def template_value(record, token)
    case token
    when "first_name" then record.try(:first_name)
    when "last_name" then record.try(:last_name)
    when "name" then record.try(:display_name) || record.try(:name)
    when "company" then record.try(:company)&.name || record.try(:person)&.company&.name
    when "email" then record.try(:email)
    else "{#{token}}"
    end.to_s
  end

  def attachments_within_limits
    return unless attachments.attached?

    if attachments.count > EmailMessage::MAX_ATTACHMENTS
      errors.add(:attachments, "cannot exceed #{EmailMessage::MAX_ATTACHMENTS} files")
      return
    end

    total = 0
    attachments.each do |file|
      if file.byte_size > EmailMessage::MAX_ATTACHMENT_SIZE
        errors.add(:attachments, "#{file.filename} exceeds #{EmailMessage::MAX_ATTACHMENT_SIZE / 1.megabyte} MB")
      end
      total += file.byte_size
    end

    if total > EmailMessage::MAX_TOTAL_ATTACHMENT_SIZE
      errors.add(:attachments, "total size cannot exceed #{EmailMessage::MAX_TOTAL_ATTACHMENT_SIZE / 1.megabyte} MB")
    end
  end
end
