import { Controller } from "@hotwired/stimulus"

// Submits the form it's attached to when a control fires its action.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
