import { Controller } from "@hotwired/stimulus"

// Sizes a sandboxed email iframe to its document, including when a closed
// <details> opens and the frame is laid out for the first time.
export default class extends Controller {
  static targets = [ "frame" ]

  connect() {
    this.onToggle = () => this.resize()
    this.details = this.element.closest("details")
    this.details?.addEventListener("toggle", this.onToggle)
  }

  disconnect() {
    this.details?.removeEventListener("toggle", this.onToggle)
  }

  resize() {
    const frame = this.frameTarget
    const doc = frame.contentDocument
    if (!doc?.documentElement) return

    const height = Math.max(doc.documentElement.scrollHeight, doc.body?.scrollHeight || 0)
    if (height < 1) return

    frame.style.height = `${Math.min(Math.max(height, 48), 1600)}px`
  }
}
