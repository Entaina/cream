class AutoLinker
  URL_PATTERN = %r{https?://[^\s<>"']+}i
  TRAILING_PUNCTUATION = /[.,;:!?)\]]+\z/

  def self.render_html(text)
    return "" if text.blank?

    segments = text.split(URL_PATTERN)
    urls = text.scan(URL_PATTERN)

    segments.each_with_index.map do |segment, index|
      processed = block_given? ? yield(escape_html(segment)) : escape_html(segment)
      next processed if index >= urls.length

      url, trailing = split_trailing_punctuation(urls[index])
      processed + link_for(url) + escape_html(trailing)
    end.join
  end

  def self.link_for(url)
    escaped_url = escape_html(url)
    %(<a href="#{escaped_url}" target="_blank" rel="noopener noreferrer" class="text-accent underline">#{escaped_url}</a>)
  end

  def self.escape_html(text)
    CGI.escapeHTML(text.to_s)
  end

  def self.split_trailing_punctuation(url)
    trailing = url[TRAILING_PUNCTUATION] || ""
    [url.sub(TRAILING_PUNCTUATION, ""), trailing]
  end
  private_class_method :link_for, :escape_html, :split_trailing_punctuation
end
