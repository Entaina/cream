import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pageSlugField"]
  static values = { pageKind: { type: String, default: "page" } }

  connect() {
    this.syncPageSlugVisibility()
  }

  syncPageSlugVisibility() {
    if (!this.hasPageSlugFieldTarget) return

    const partialChecked = this.element.querySelector('input[type="checkbox"][name="lead_form_template[partial]"]')?.checked
    const kind = this.element.querySelector('select[name="lead_form_template[kind]"]')?.value
    const show = kind === this.pageKindValue && !partialChecked

    this.pageSlugFieldTarget.classList.toggle("hidden", !show)
  }
}
