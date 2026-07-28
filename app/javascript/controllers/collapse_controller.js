import { Controller } from "@hotwired/stimulus"

// Toggle visibility of a panel (e.g. collapsible event type cards).
export default class extends Controller {
  static targets = [ "panel", "icon" ]
  static values = { open: Boolean }

  connect() {
    this.sync()
  }

  toggle(event) {
    event.preventDefault()
    this.openValue = !this.openValue
  }

  stop(event) {
    event.stopPropagation()
  }

  openValueChanged() {
    this.sync()
  }

  sync() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden", !this.openValue)
    }
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-90", this.openValue)
    }
  }
}
