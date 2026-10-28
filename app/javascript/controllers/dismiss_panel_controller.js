import { Controller } from "@hotwired/stimulus"

// Empties the panel but keeps the element, so later Turbo Stream updates can still target it.
export default class extends Controller {
  dismiss() {
    this.element.replaceChildren()
  }
}
