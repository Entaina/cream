# Normalizes company names and domains for duplicate detection.
class CompanyNameNormalizer
  LEGAL_TOKENS = %w[
    sa s.a. s.l. sl ltd llc inc corp co gmbh ag plc lp llp
  ].freeze

  GEO_TOKENS = %w[
    espana españa spain mexico usa uk france deutschland italia portugal
    brasil brazil argentina chile colombia peru
  ].freeze

  STRIP_TOKENS = (LEGAL_TOKENS + GEO_TOKENS).freeze

  def self.normalize(name)
    return "" if name.blank?

    name.to_s
      .unicode_normalize(:nfkd)
      .gsub(/\p{M}/, "")
      .downcase
      .gsub(/[^\p{L}\p{N}\s]/, " ")
      .split
      .reject { |token| STRIP_TOKENS.include?(token) }
      .join(" ")
      .squeeze(" ")
      .strip
  end

  def self.normalize_domain(domain)
    return "" if domain.blank?

    domain.to_s
      .strip
      .downcase
      .sub(/\Awww\./, "")
  end
end
