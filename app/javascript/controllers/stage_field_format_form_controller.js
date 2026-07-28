import { Controller } from "@hotwired/stimulus"

// Hides the compare value field when the chosen operator needs no operand
// ("está vacío").
export default class extends Controller {
  static targets = ["operator", "compareValue"]

  connect() {
    this.refresh()
  }

  refresh() {
    if (this.hasCompareValueTarget) {
      this.compareValueTarget.hidden = this.operatorTarget.value === "blank"
    }
  }
}
