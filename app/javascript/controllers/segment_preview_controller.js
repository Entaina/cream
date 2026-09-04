import { Controller } from "@hotwired/stimulus"

// Fetches a live recipient/member count from the server (debounced).
export default class extends Controller {
  static targets = ["count", "segmentId"]
  static values = { url: String, paramName: { type: String, default: "segment_id" } }

  connect() {
    if (this.hasUrlValue && this.urlValue) this.refresh()
  }

  segmentChanged() {
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => this.refresh(), 300)
  }

  async refresh() {
    if (!this.hasCountTarget || !this.urlValue) return

    if (this.hasSegmentIdTarget && !this.segmentIdTarget.value) {
      this.countTarget.textContent = "—"
      return
    }

    let url = this.urlValue
    if (this.hasSegmentIdTarget && this.segmentIdTarget.value) {
      const params = new URLSearchParams()
      params.set(this.paramNameValue, this.segmentIdTarget.value)
      url = `${url}?${params}`
    }

    this.countTarget.textContent = "…"
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(response.statusText)
      const data = await response.json()
      const count = data.count ?? 0
      this.countTarget.textContent = count.toLocaleString("es-ES")
    } catch {
      this.countTarget.textContent = "—"
    }
  }

  disconnect() {
    clearTimeout(this.debounce)
  }
}
