import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sourcePage",
    "referrer",
    "utmSource",
    "utmMedium",
    "utmCampaign",
    "utmTerm",
    "utmContent",
    "corporateEmailAlert"
  ]

  static values = {
    requireCorporateEmail: Boolean,
    blockedDomains: Array,
    corporateEmailMessage: String
  }

  connect() {
    this.setIfEmpty("referrerTarget", document.referrer || "")
    this.setIfEmpty("sourcePageTarget", window.location.href)

    const params = new URLSearchParams(window.location.search)
    this.setIfEmpty("utmSourceTarget", params.get("utm_source"))
    this.setIfEmpty("utmMediumTarget", params.get("utm_medium"))
    this.setIfEmpty("utmCampaignTarget", params.get("utm_campaign"))
    this.setIfEmpty("utmTermTarget", params.get("utm_term"))
    this.setIfEmpty("utmContentTarget", params.get("utm_content"))

    this.element.querySelectorAll("[data-lead-form-param]").forEach((input) => {
      const param = input.dataset.leadFormParam
      if (!param || input.value) return

      const value = params.get(param)
      if (value) input.value = value
    })
  }

  validateCorporateEmail(event) {
    if (!this.requireCorporateEmailValue) return

    const input = this.emailInput()
    if (!input) return

    const domain = this.extractDomain(input.value)
    if (!domain || !this.isBlockedDomain(domain)) {
      this.clearCorporateEmailError()
      return
    }

    event.preventDefault()
    const message = this.corporateEmailMessageValue
    input.setCustomValidity(message)
    input.reportValidity()
    this.showCorporateEmailAlert(message)
  }

  clearCorporateEmailError() {
    const input = this.emailInput()
    if (input) input.setCustomValidity("")
    this.hideCorporateEmailAlert()
  }

  emailInput() {
    return (
      this.element.querySelector('input[name="lead[email]"]') ||
      this.element.querySelector('input[type="email"]')
    )
  }

  extractDomain(email) {
    const parts = email.trim().toLowerCase().split("@")
    if (parts.length !== 2 || !parts[1]) return null
    return parts[1]
  }

  isBlockedDomain(domain) {
    const blocked = this.blockedDomainsValue || []
    return blocked.includes(domain)
  }

  showCorporateEmailAlert(message) {
    if (!this.hasCorporateEmailAlertTarget) return
    this.corporateEmailAlertTarget.textContent = message
    this.corporateEmailAlertTarget.classList.remove("hidden")
  }

  hideCorporateEmailAlert() {
    if (!this.hasCorporateEmailAlertTarget) return
    this.corporateEmailAlertTarget.textContent = ""
    this.corporateEmailAlertTarget.classList.add("hidden")
  }

  setIfEmpty(targetKey, value) {
    if (!value) return

    const target = this[targetKey]
    if (target && !target.value) target.value = value
  }
}
