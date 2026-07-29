import { Controller } from "@hotwired/stimulus"

// Submits the form it's attached to when a control fires its action.
export default class extends Controller {
  submit(event) {
    if (event.type === "change" && event.target.matches("input[data-record-picker-target='hidden']")) {
      // record-picker clears the hidden on every keystroke; ignore until a real pick.
      return
    }

    this.element.requestSubmit()
  }
}
