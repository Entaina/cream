import { Controller } from "@hotwired/stimulus"

// Adds/removes nested fields_for rows (e.g. pipeline stages, deal product lines).
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    const index = new Date().getTime()
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, index)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.dispatch("changed", { bubbles: true })
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-nested-form-target='row']")
    if (!row) return

    const destroyField = row.querySelector("input[name*='[_destroy]']")
    if (destroyField) {
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }
    this.dispatch("changed", { bubbles: true })
  }
}
