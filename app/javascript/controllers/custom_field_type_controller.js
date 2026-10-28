import { Controller } from "@hotwired/stimulus"

// Shows the settings panel that matches the selected custom field type.
export default class extends Controller {
  toggle() {
    const type = this.element.value
    document.getElementById("custom-field-options-panel")?.classList.toggle("hidden", !["select", "multi_select"].includes(type))
    document.getElementById("custom-field-formula-panel")?.classList.toggle("hidden", type !== "formula")
    document.getElementById("custom-field-reference-panel")?.classList.toggle("hidden", type !== "record_reference")
  }
}
