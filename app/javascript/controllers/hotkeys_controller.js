import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts: "/" jumps to search.
export default class extends Controller {
  static values = { searchUrl: String }

  connect() {
    this.onKeydown = (event) => {
      if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey) return
      const target = event.target
      if (target.closest("input, textarea, select, [contenteditable]")) return
      event.preventDefault()
      window.Turbo.visit(this.searchUrlValue)
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }
}
