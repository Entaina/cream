import { Controller } from "@hotwired/stimulus"

// Shows entry_config and step config fields relevant to the selected trigger/step type.
export default class extends Controller {
  static targets = ["trigger", "entryField", "stepRow", "stepType", "stepField"]

  connect() {
    this.refreshEntryFields()
    this.stepRowTargets.forEach((row) => this.refreshStepFieldsForRow(row))
  }

  triggerChanged() {
    this.refreshEntryFields()
  }

  stepTypeChanged(event) {
    const row = event.target.closest("[data-journey-form-target='stepRow']")
    if (row) this.refreshStepFieldsForRow(row)
  }

  stepAdded() {
    const rows = this.stepRowTargets
    if (rows.length) this.refreshStepFieldsForRow(rows[rows.length - 1])
  }

  refreshEntryFields() {
    if (!this.hasTriggerTarget) return
    const trigger = this.triggerTarget.value
    this.entryFieldTargets.forEach((el) => {
      el.hidden = el.dataset.trigger !== trigger
    })
  }

  refreshStepFieldsForRow(row) {
    const stepTypeSelect = row.querySelector("[data-journey-form-target='stepType']")
    if (!stepTypeSelect) return
    const stepType = stepTypeSelect.value
    row.querySelectorAll("[data-journey-form-target='stepField']").forEach((el) => {
      el.hidden = el.dataset.stepType !== stepType
    })
  }
}
