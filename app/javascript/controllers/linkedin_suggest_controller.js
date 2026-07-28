import { Controller } from "@hotwired/stimulus"

// Opens LinkedIn search in a new tab with keywords from the person/company form.
export default class extends Controller {
  static values = { entity: String }

  search(event) {
    const keywords = this.keywords()
    if (!keywords) {
      event.currentTarget.title = "Escribe un nombre antes de buscar"
      return
    }

    const path = this.entityValue === "company" ? "companies" : "people"
    const url = `https://www.linkedin.com/search/results/${path}/?keywords=${encodeURIComponent(keywords)}`
    window.open(url, "_blank", "noopener")
  }

  keywords() {
    if (this.entityValue === "company") {
      return this.fieldValue("company[name]")
    }

    const personName = [this.fieldValue("person[first_name]"), this.fieldValue("person[last_name]")]
      .filter(Boolean)
      .join(" ")
    if (!personName) return ""

    const companyName = this.selectedOptionText('select[name="person[company_id]"]')
    return [personName, companyName].filter(Boolean).join(" ")
  }

  fieldValue(name) {
    const input = this.element.querySelector(`[name="${name}"]`)
    return input?.value?.trim() || ""
  }

  selectedOptionText(selector) {
    const select = this.element.querySelector(selector)
    if (!select?.value) return ""

    const option = select.options[select.selectedIndex]
    return option?.text?.trim() || ""
  }
}
