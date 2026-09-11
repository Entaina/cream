import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "composer"]

  connect() {
    this.dirtyForms = new Set()
    this.submitting = false
  }

  selectTab(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    const key = event.currentTarget.dataset.tab
    this.tabTargets.forEach(tab => {
      const selected = tab.dataset.tab === key
      tab.setAttribute("aria-selected", selected)
      tab.tabIndex = selected ? 0 : -1
    })
    this.panelTargets.forEach(panel => { panel.hidden = panel.id !== `record-panel-${key}` })
    const url = new URL(window.location.href)
    url.searchParams.set("tab", key)
    window.history.replaceState(window.history.state, "", url)
    if (event.currentTarget.getAttribute("role") !== "tab") {
      this.tabTargets.find(tab => tab.dataset.tab === key)?.focus()
    }
  }

  navigateTabs(event) {
    const keys = ["ArrowLeft", "ArrowRight", "Home", "End"]
    if (!keys.includes(event.key)) return
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    const count = this.tabTargets.length
    const next = event.key === "Home" ? 0 : event.key === "End" ? count - 1 : (index + (event.key === "ArrowRight" ? 1 : -1) + count) % count
    this.tabTargets[next].focus()
    this.tabTargets[next].click()
  }

  openComposer(event) {
    const dialog = this.composerTargets.find(item => item.dataset.composer === event.currentTarget.dataset.composer)
    if (!dialog) return
    this.opener = event.currentTarget
    dialog.showModal()
    dialog.querySelector("input:not([type=hidden]), textarea, [contenteditable=true]")?.focus()
  }

  closeComposer(event) {
    event.currentTarget.closest("dialog").close()
  }

  composerClosed() {
    this.opener?.focus()
  }

  markDirty(event) {
    const form = event.target.closest("form")
    if (form && form.method !== "get") this.dirtyForms.add(form)
  }

  submit(event) {
    const others = [...this.dirtyForms].filter(form => form !== event.target)
    if (others.length && !window.confirm("You have other unsaved drafts. Leave them and continue?")) {
      event.preventDefault()
      return
    }
    this.submitting = true
  }

  submitted(event) {
    this.submitting = false
    if (event.detail.success) this.dirtyForms.delete(event.target)
  }

  beforeVisit(event) {
    if (this.dirtyForms.size && !this.submitting && !window.confirm("Leave this page? Your unsaved changes and drafts will be lost.")) event.preventDefault()
  }

  beforeUnload(event) {
    if (!this.dirtyForms.size || this.submitting) return
    event.preventDefault()
    event.returnValue = ""
  }
}
