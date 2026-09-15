module LeadSubmissionsHelper
  ACCEPTED_POLICY_TAGS = %w[
    p br strong em b i u a ul ol li h1 h2 h3 h4 h5 h6
    div section article header footer span blockquote hr
    table thead tbody tr th td label
  ].freeze
  ACCEPTED_POLICY_ATTRIBUTES = %w[href title].freeze

  def sanitize_accepted_policy_html(html)
    return "" if html.blank?

    fragment = Nokogiri::HTML.fragment(html.to_s)
    fragment.css("style, script, noscript, iframe, object, embed, link").remove
    sanitize(fragment.to_html, tags: ACCEPTED_POLICY_TAGS, attributes: ACCEPTED_POLICY_ATTRIBUTES)
  end
end
