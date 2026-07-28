import { Controller } from "@hotwired/stimulus"

// Auto-dismiss flash messages.
export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), 4000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transition = "opacity 300ms"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
