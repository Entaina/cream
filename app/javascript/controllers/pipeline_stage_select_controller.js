import { Controller } from "@hotwired/stimulus"

// Filters pipeline stage options when the pipeline changes on the new-deal form.
export default class extends Controller {
  static targets = ["pipeline", "stage"]

  connect() {
    this.pipelineChanged()
  }

  pipelineChanged() {
    const pipelineId = this.pipelineTarget.value
    const stageSelect = this.stageTarget
    let firstVisible = null

    Array.from(stageSelect.options).forEach(option => {
      const belongs = option.dataset.pipelineId === pipelineId
      option.hidden = !belongs
      option.disabled = !belongs
      if (belongs && !firstVisible) firstVisible = option
    })

    const selected = stageSelect.selectedOptions[0]
    if (!selected || selected.hidden) {
      if (firstVisible) stageSelect.value = firstVisible.value
    }
  }
}
