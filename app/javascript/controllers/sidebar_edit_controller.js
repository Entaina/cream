import { Controller } from "@hotwired/stimulus"

// Sidebar nav customization: reorder items and toggle visibility per user.
export default class extends Controller {
  static targets = ["list", "item", "handle", "link", "visibilityBtn", "eyeIcon", "eyeOffIcon", "toggleBtn"]
  static values = { url: String, editing: { type: Boolean, default: false } }

  connect() {
    this.onPointerMove = this.onPointerMove.bind(this)
    this.onPointerUp = this.onPointerUp.bind(this)
    this.saveTimeout = null
  }

  disconnect() {
    this.stopDrag()
    clearTimeout(this.saveTimeout)
  }

  toggleEdit(event) {
    event.preventDefault()
    this.editingValue = !this.editingValue
  }

  editingValueChanged(editing) {
    this.element.classList.toggle("sidebar-editing", editing)
    this.handleTargets.forEach((el) => el.classList.toggle("hidden", !editing))
    this.visibilityBtnTargets.forEach((el) => el.classList.toggle("hidden", !editing))
    this.linkTargets.forEach((el) => el.classList.toggle("pointer-events-none", editing))
    this.toggleBtnTarget.setAttribute("aria-pressed", editing ? "true" : "false")
    this.toggleBtnTarget.classList.toggle("text-accent", editing)
    this.toggleBtnTarget.classList.toggle("bg-accent-soft", editing)

    this.itemTargets.forEach((item) => this.applyItemVisibility(item, editing))

    if (!editing) {
      this.save()
    }
  }

  applyItemVisibility(item, editing = this.editingValue) {
    const hidden = item.dataset.hidden === "true"
    item.classList.toggle("hidden", hidden && !editing)
    item.classList.toggle("opacity-40", hidden && editing)
  }

  preventNav(event) {
    if (this.editingValue) event.preventDefault()
  }

  pointerDown(event) {
    if (!this.editingValue || event.button !== 0) return

    this.dragged = event.target.closest("[data-sidebar-edit-target='item']")
    if (!this.dragged) return

    event.preventDefault()
    this.dragged.classList.add("opacity-50")
    document.addEventListener("pointermove", this.onPointerMove)
    document.addEventListener("pointerup", this.onPointerUp)
  }

  onPointerMove(event) {
    if (!this.dragged) return

    const list = this.draggedList()
    const row = document.elementFromPoint(event.clientX, event.clientY)
      ?.closest("[data-sidebar-edit-target='item']")

    if (row && row !== this.dragged && list.contains(row)) {
      this.moveRelativeTo(row)
      return
    }

    this.reorderByPointer(event.clientY)
  }

  onPointerUp() {
    this.dragged?.classList.remove("opacity-50")
    this.stopDrag()
    this.scheduleSave()
  }

  stopDrag() {
    document.removeEventListener("pointermove", this.onPointerMove)
    document.removeEventListener("pointerup", this.onPointerUp)
    this.dragged = null
  }

  moveRelativeTo(targetRow) {
    const rows = this.rows()
    const draggedIndex = rows.indexOf(this.dragged)
    const targetIndex = rows.indexOf(targetRow)
    if (draggedIndex === -1 || targetIndex === -1) return

    if (draggedIndex < targetIndex) {
      targetRow.after(this.dragged)
    } else {
      targetRow.before(this.dragged)
    }
  }

  reorderByPointer(clientY) {
    const rows = this.rows().filter((row) => row !== this.dragged)
    for (const row of rows) {
      const rect = row.getBoundingClientRect()
      const mid = rect.top + rect.height / 2
      if (clientY < mid) {
        row.before(this.dragged)
        return
      }
    }

    const last = rows[rows.length - 1]
    if (last) last.after(this.dragged)
  }

  draggedList() {
    return this.dragged.closest("[data-sidebar-edit-target='list']")
  }

  rows() {
    const list = this.draggedList()
    if (!list) return []

    return [...list.querySelectorAll("[data-sidebar-edit-target='item']")]
  }

  toggleVisibility(event) {
    event.preventDefault()
    event.stopPropagation()

    const item = event.target.closest("[data-sidebar-edit-target='item']")
    if (!item) return

    const hidden = item.dataset.hidden !== "true"
    item.dataset.hidden = hidden ? "true" : "false"
    this.updateVisibilityIcons(item)
    this.applyItemVisibility(item)
    this.scheduleSave()
  }

  updateVisibilityIcons(item) {
    const hidden = item.dataset.hidden === "true"
    const eyeIcon = item.querySelector("[data-sidebar-edit-target='eyeIcon']")
    const eyeOffIcon = item.querySelector("[data-sidebar-edit-target='eyeOffIcon']")
    eyeIcon?.classList.toggle("hidden", hidden)
    eyeOffIcon?.classList.toggle("hidden", !hidden)
  }

  scheduleSave() {
    if (!this.editingValue) return

    clearTimeout(this.saveTimeout)
    this.saveTimeout = setTimeout(() => this.save(), 500)
  }

  async save() {
    const order = this.listTargets.flatMap((list) =>
      [...list.querySelectorAll("[data-sidebar-edit-target='item']")].map((item) => item.dataset.key)
    )
    const hidden = this.itemTargets
      .filter((item) => item.dataset.hidden === "true")
      .map((item) => item.dataset.key)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ order, hidden })
      })

      if (!response.ok) {
        console.error("Failed to save sidebar preferences", response.status)
      }
    } catch (error) {
      console.error("Failed to save sidebar preferences", error)
    }
  }
}
