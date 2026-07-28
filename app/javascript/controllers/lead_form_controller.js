import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sourcePage",
    "referrer",
    "utmSource",
    "utmMedium",
    "utmCampaign",
    "utmTerm",
    "utmContent"
  ]

  connect() {
    this.setIfEmpty("referrerTarget", document.referrer || "")
    this.setIfEmpty("sourcePageTarget", window.location.href)

    const params = new URLSearchParams(window.location.search)
    this.setIfEmpty("utmSourceTarget", params.get("utm_source"))
    this.setIfEmpty("utmMediumTarget", params.get("utm_medium"))
    this.setIfEmpty("utmCampaignTarget", params.get("utm_campaign"))
    this.setIfEmpty("utmTermTarget", params.get("utm_term"))
    this.setIfEmpty("utmContentTarget", params.get("utm_content"))
  }

  setIfEmpty(targetKey, value) {
    if (!value) return

    const target = this[targetKey]
    if (target && !target.value) target.value = value
  }
}
