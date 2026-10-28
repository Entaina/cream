class EmailLayout < ApplicationRecord
  CONTENT_PLACEHOLDER = /\{\{\s*content\s*\}\}|\{content\}/

  belongs_to :workspace
  has_many :email_templates, dependent: :nullify

  validates :name, :body, presence: true
  validate :body_must_include_content_placeholder

  scope :ordered, -> { order(:name, :id) }

  # Tokens are resolved in the layout before the content goes in, so token-like
  # text inside already rendered content is never interpolated a second time.
  def render_with(content_html, record:, extra_tokens: {}, escape_html: false)
    marker = "cream-layout-content-#{SecureRandom.hex(8)}"
    layout = if body.include?("{{") || body.include?("{%")
      tokens = extra_tokens.stringify_keys.merge("content" => marker)
      Marketing::LiquidRenderer.render(body, record: record, extra_tokens: tokens, escape_html: escape_html)
    else
      body.gsub(CONTENT_PLACEHOLDER, marker)
    end
    EmailTemplate.interpolate_string(layout, record, extra_tokens, escape_html: escape_html).gsub(marker) { content_html.to_s }
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
