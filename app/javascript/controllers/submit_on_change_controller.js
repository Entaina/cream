import { Controller } from "@hotwired/stimulus"

// Submits the field's form when its value changes (filter bars, inline selects).
export default class extends Controller {
  submit() {
    this.element.form?.requestSubmit()
  }
}
