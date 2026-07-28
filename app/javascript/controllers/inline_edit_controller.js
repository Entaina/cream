import { Controller } from "@hotwired/stimulus"

// Toggle display ↔ editor for a table cell. Saves via Turbo on value change;
// Escape cancels. Stops row click navigation while interacting with the cell.
export default class extends Controller {
  static targets = [ "display", "editor", "form", "error" ]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    if (this.openValue) this.showEditor()
  }

  disconnect() {
    this.restoreOverflow()
  }

  stop(event) {
    event.stopPropagation()
  }

  edit(event) {
    event.preventDefault()
    event.stopPropagation()
    this.showEditor()
  }

  cancel(event) {
    if (event.key !== "Escape") return
    if (this.editorTarget.classList.contains("hidden")) return

    // First Escape closes an open record-picker menu; a second one cancels edit.
    const menu = this.editorTarget.querySelector("[data-record-picker-target='menu']")
    if (menu && !menu.classList.contains("hidden")) return

    event.preventDefault()
    this.hideEditor()
  }

  // Owner <select> and record-picker:selected both land here.
  submit(event) {
    if (event.type === "change" && event.target.matches("input[data-record-picker-target='hidden']")) {
      // record-picker clears the hidden on every keystroke; ignore until a real pick.
      return
    }

    if (!this.hasFormTarget) return
    this.formTarget.requestSubmit()
  }

  showEditor() {
    this.displayTarget.classList.add("hidden")
    this.editorTarget.classList.remove("hidden")
    this.allowOverflow()

    requestAnimationFrame(() => {
      const focusable = this.editorTarget.querySelector("input:not([type=hidden]), select")
      focusable?.focus()
      if (focusable?.tagName === "SELECT") focusable.click()
    })
  }

  hideEditor() {
    this.editorTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
    this.clearError()
    this.restoreOverflow()
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  allowOverflow() {
    this.restoreOverflow()
    this.overflowAncestors = []
    let el = this.element.parentElement
    while (el && el !== document.body) {
      const style = getComputedStyle(el)
      if ([ "auto", "hidden", "scroll" ].includes(style.overflowY) || [ "auto", "hidden", "scroll" ].includes(style.overflow)) {
        this.overflowAncestors.push([ el, el.style.overflow, el.style.overflowY ])
        el.style.overflow = "visible"
        el.style.overflowY = "visible"
      }
      el = el.parentElement
    }
  }

  restoreOverflow() {
    if (!this.overflowAncestors) return
    this.overflowAncestors.forEach(([ el, overflow, overflowY ]) => {
      el.style.overflow = overflow
      el.style.overflowY = overflowY
    })
    this.overflowAncestors = []
  }
}
