import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
    const input = this.dialogTarget.querySelector("input[type=text], textarea, select")
    input?.focus()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }
}
