import { Controller } from "@hotwired/stimulus"

// Syncs payment date with execution start when payment method is cash.
export default class extends Controller {
  static targets = ["executionStarts", "paymentMethod", "paymentOn"]

  connect() {
    this.refresh()
  }

  executionStartChanged() {
    this.refresh()
  }

  paymentMethodChanged() {
    this.refresh()
  }

  refresh() {
    if (!this.hasPaymentOnTarget) return

    const isCash = this.hasPaymentMethodTarget && this.paymentMethodTarget.value === "cash"
    if (isCash) {
      if (this.hasExecutionStartsTarget) {
        this.paymentOnTarget.value = this.executionStartsTarget.value
      }
      this.paymentOnTarget.readOnly = true
      this.paymentOnTarget.setAttribute("aria-readonly", "true")
    } else {
      this.paymentOnTarget.readOnly = false
      this.paymentOnTarget.removeAttribute("aria-readonly")
    }
  }
}
