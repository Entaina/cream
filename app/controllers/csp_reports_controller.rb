# Receives Content-Security-Policy violation reports from browsers and logs one
# "[CSP]" line per violation. Handles both the legacy report-uri format
# (application/csp-report) and the Reporting API format (application/reports+json).
class CspReportsController < ActionController::API
  MAX_BODY_BYTES = 16.kilobytes
  MAX_VALUE_LENGTH = 300

  rate_limit to: 60, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  def create
    violations.each { |violation| Rails.logger.warn("[CSP] #{violation.to_json}") }
    head :no_content
  end

  private

  def violations
    body = request.body.read(MAX_BODY_BYTES).to_s
    payload = JSON.parse(body)
    reports = case payload
    when Array then payload.filter_map { |report| report["body"] if report.is_a?(Hash) }
    when Hash then [payload["csp-report"]]
    else []
    end
    reports.select { |report| report.is_a?(Hash) }.map { |report| normalize(report) }
  rescue JSON::ParserError
    []
  end

  # Query strings are dropped: they can carry tokens.
  def normalize(report)
    {
      page: without_query(report["documentURL"] || report["document-uri"]),
      directive: report["effectiveDirective"] || report["effective-directive"] || report["violated-directive"],
      blocked: without_query(report["blockedURL"] || report["blocked-uri"]),
      source: without_query(report["sourceFile"] || report["source-file"]),
      line: report["lineNumber"] || report["line-number"],
      sample: report["sample"] || report["script-sample"],
      disposition: report["disposition"]
    }.compact_blank.transform_values { |value| value.to_s.truncate(MAX_VALUE_LENGTH) }
  end

  def without_query(url)
    url&.to_s&.split(/[?#]/, 2)&.first
  end
end
