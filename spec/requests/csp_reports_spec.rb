require "rails_helper"

RSpec.describe "CSP violation reports", type: :request do
  let(:logged) { [] }

  before do
    allow(Rails.logger).to receive(:warn).and_call_original
    allow(Rails.logger).to receive(:warn).with(a_string_starting_with("[CSP]")) { |line| logged << line }
  end

  def logged_violations
    logged.map { |line| JSON.parse(line.delete_prefix("[CSP] ")) }
  end

  it "logs legacy report-uri reports without query strings" do
    report = {
      "csp-report" => {
        "document-uri" => "https://crm.example.com/deals?token=secret",
        "effective-directive" => "script-src-attr",
        "violated-directive" => "script-src-attr",
        "blocked-uri" => "inline",
        "source-file" => "https://crm.example.com/deals?x=1",
        "line-number" => 12,
        "script-sample" => "this.form.requestSubmit()"
      }
    }

    post csp_reports_path, params: report.to_json, headers: {"CONTENT_TYPE" => "application/csp-report"}

    expect(response).to have_http_status(:no_content)
    expect(logged_violations).to eq([{
      "page" => "https://crm.example.com/deals",
      "directive" => "script-src-attr",
      "blocked" => "inline",
      "source" => "https://crm.example.com/deals",
      "line" => "12",
      "sample" => "this.form.requestSubmit()"
    }])
  end

  it "logs every violation of a Reporting API batch" do
    reports = [
      {"type" => "csp-violation", "body" => {"documentURL" => "https://crm.example.com/", "effectiveDirective" => "script-src-elem", "blockedURL" => "https://evil.example/x.js", "disposition" => "report"}},
      {"type" => "csp-violation", "body" => {"documentURL" => "https://crm.example.com/people", "effectiveDirective" => "img-src", "blockedURL" => "http://img.example/a.png", "disposition" => "report"}}
    ]

    post csp_reports_path, params: reports.to_json, headers: {"CONTENT_TYPE" => "application/reports+json"}

    expect(response).to have_http_status(:no_content)
    expect(logged_violations.map { |violation| violation["directive"] }).to eq(%w[script-src-elem img-src])
    expect(logged_violations.first["blocked"]).to eq("https://evil.example/x.js")
  end

  it "ignores bodies that are not JSON reports" do
    post csp_reports_path, params: "not json", headers: {"CONTENT_TYPE" => "application/csp-report"}

    expect(response).to have_http_status(:no_content)
    expect(logged).to be_empty
  end
end
