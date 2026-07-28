import { Controller } from "@hotwired/stimulus"

// Shows the hint and action fields relevant to the selected trigger/action,
// so the automation form is contextual instead of raw JSON.
export default class extends Controller {
  static targets = ["trigger", "actionType", "hint", "actionFields"]

  connect() {
    this.refresh()
  }

  refresh() {
    const trigger = this.hasTriggerTarget ? this.triggerTarget.value : null
    this.hintTargets.forEach((el) => {
      el.hidden = el.dataset.trigger !== trigger
    })

    const action = this.hasActionTypeTarget ? this.actionTypeTarget.value : null
    this.actionFieldsTargets.forEach((el) => {
      el.hidden = el.dataset.actionType !== action
    })
  }
}
