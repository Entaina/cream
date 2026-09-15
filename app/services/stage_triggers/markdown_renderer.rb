module StageTriggers
  # Single rendering point for trigger-generated markdown. Content may come
  # from an LLM fed with CRM data, so it is treated as untrusted: raw HTML is
  # filtered by Redcarpet and the result passes through the Rails sanitizer.
  class MarkdownRenderer
    ALLOWED_TAGS = %w[p br strong em ul ol li a h1 h2 h3 h4 code pre blockquote].freeze
    ALLOWED_ATTRIBUTES = %w[href].freeze

    def self.render(markdown)
      return "" if markdown.blank?

      renderer = Redcarpet::Render::HTML.new(filter_html: true,
        link_attributes: {rel: "noopener noreferrer", target: "_blank"})
      html = Redcarpet::Markdown.new(renderer, autolink: true, tables: false).render(markdown)
      ActionController::Base.helpers.sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
    end
  end
end
