import { Controller } from "@hotwired/stimulus"

const INTERACTIVE_SELECTOR = "a, button, input, select, textarea, label"

// Whole-table-row navigation: plain click uses Turbo; cmd/ctrl+click and middle-click open a new tab.
export default class extends Controller {
  static values = { url: String }

  navigate(event) {
    if (event.defaultPrevented) return
    if (event.target.closest(INTERACTIVE_SELECTOR)) return

    const url = this.urlValue
    if (!url) return

    const openInNewTab =
      event.metaKey ||
      event.ctrlKey ||
      (event.type === "auxclick" && event.button === 1)

    if (openInNewTab) {
      event.preventDefault()
      window.open(url, "_blank", "noopener")
      return
    }

    if (event.type === "auxclick") return
    if (event.button !== 0) return

    event.preventDefault()
    Turbo.visit(url)
  }
}
