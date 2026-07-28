import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["operator", "compareValue"]

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.hasCompareValueTarget) return

    this.compareValueTarget.hidden = this.blankOrPresentOperator()
  }

  blankOrPresentOperator() {
    return [ "blank", "present" ].includes(this.operatorTarget.value)
  }
}
