import { Controller } from "@hotwired/stimulus"

// Keeps the report builder's measure/group-by options valid for the selected
// record type, and re-runs the report (submits the GET form) on any change.
export default class extends Controller {
  static targets = ["recordType", "metric", "groupBy", "pipelineField"]

  connect() {
    this.filterOptions()
  }

  recordTypeChanged() {
    this.filterOptions()
    this.submit()
  }

  submit() {
    this.element.requestSubmit()
  }

  filterOptions() {
    const type = this.recordTypeTarget.value
    this.togglePipelineField(type)
    ;[this.metricTarget, this.groupByTarget].forEach((select) => {
      let firstVisible = null
      Array.from(select.options).forEach((option) => {
        const ok = (option.dataset.types || "").split(" ").includes(type)
        option.hidden = !ok
        option.disabled = !ok
        if (ok && !firstVisible) firstVisible = option
      })
      const current = select.selectedOptions[0]
      if ((!current || current.hidden) && firstVisible) select.value = firstVisible.value
    })
  }

  togglePipelineField(type) {
    if (!this.hasPipelineFieldTarget) return

    const show = type === "Deal"
    this.pipelineFieldTarget.classList.toggle("hidden", !show)
    if (!show) {
      const select = this.pipelineFieldTarget.querySelector("select")
      if (select) select.value = ""
    }
  }
}
