import { Controller } from "@hotwired/stimulus"

// Drives the mail merge recipient picker: shows the manual-IDs block only when
// the "manual" source is chosen, and fetches a live recipient count from the
// server whenever the selected source (or manual input) changes.
export default class extends Controller {
  static targets = ["source", "manual", "count", "recordType", "recordIds"]
  static values = {
    countUrl: String,
    countOne: String,
    countOther: String,
    loading: String
  }

  connect() {
    this.toggleManual()
    this.refreshCount()
  }

  sourceChanged() {
    this.toggleManual()
    this.refreshCount()
  }

  manualChanged() {
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => this.refreshCount(), 300)
  }

  toggleManual() {
    if (!this.hasManualTarget) return
    this.manualTarget.hidden = this.sourceTarget.value !== "manual"
  }

  async refreshCount() {
    if (!this.hasCountTarget) return

    const params = new URLSearchParams({ source: this.sourceTarget.value })
    if (this.sourceTarget.value === "manual") {
      if (this.hasRecordTypeTarget) params.set("record_type", this.recordTypeTarget.value)
      if (this.hasRecordIdsTarget) params.set("record_ids", this.recordIdsTarget.value)
    }

    this.countTarget.textContent = this.loadingValue
    try {
      const response = await fetch(`${this.countUrlValue}?${params}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) throw new Error(response.statusText)
      const data = await response.json()
      this.countTarget.textContent = data.count === 1
        ? this.countOneValue
        : this.countOtherValue.replace("%{count}", data.count)
    } catch {
      this.countTarget.textContent = "—"
    }
  }
}
