import { Controller } from "@hotwired/stimulus"

// Persists open/closed state for collapsible sidebar groups.
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("details[data-sidebar-group]").forEach((details) => {
      const group = details.dataset.sidebarGroup
      const stored = localStorage.getItem(this.storageKey(group))

      if (stored === "open") {
        details.open = true
      } else if (stored === "closed") {
        details.open = false
      } else if (details.dataset.active === "true") {
        details.open = true
      }

      details.addEventListener("toggle", () => {
        localStorage.setItem(this.storageKey(group), details.open ? "open" : "closed")
      })
    })
  }

  storageKey(group) {
    return `cream-sidebar-group-${group}`
  }
}
