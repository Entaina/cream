class EmailLayout < ApplicationRecord
  CONTENT_PLACEHOLDER = /\{\{\s*content\s*\}\}|\{content\}/

  belongs_to :workspace
  has_many :email_templates, dependent: :nullify

  validates :name, :body, presence: true
  validate :body_must_include_content_placeholder

  scope :ordered, -> { order(:name, :id) }

  def render_with(content_html, record:, extra_tokens: {})
    rendered = content_html.to_s
    if body.include?("{{") || body.include?("{%")
      tokens = extra_tokens.stringify_keys.merge("content" => rendered)
      rendered = Marketing::LiquidRenderer.render(body, record: record, extra_tokens: tokens)
    else
      rendered = body.gsub(CONTENT_PLACEHOLDER, rendered)
    end
    EmailTemplate.interpolate_string(rendered, record, extra_tokens)
  end

  def preview_body_for(template_body)
    body.gsub(CONTENT_PLACEHOLDER, template_body.to_s)
  end

  private

  def body_must_include_content_placeholder
    return if body.blank?

    return if body.match?(CONTENT_PLACEHOLDER)

    errors.add(:body, I18n.t("email_templates.layouts.errors.content_placeholder"))
  end
end
