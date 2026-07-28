import { Controller } from "@hotwired/stimulus"

// Reorders nested-form rows via drag handle; keeps hidden position fields in sync.
export default class extends Controller {
  static targets = ["list", "handle"]

  connect() {
    this.onPointerMove = this.onPointerMove.bind(this)
    this.onPointerUp = this.onPointerUp.bind(this)
    this.updatePositions()
  }

  pointerDown(event) {
    if (event.button !== 0) return

    this.dragged = event.target.closest("[data-nested-form-target='row']")
    if (!this.dragged) return

    event.preventDefault()
    this.dragged.classList.add("opacity-50")
    document.addEventListener("pointermove", this.onPointerMove)
    document.addEventListener("pointerup", this.onPointerUp)
  }

  onPointerMove(event) {
    if (!this.dragged) return

    const row = document.elementFromPoint(event.clientX, event.clientY)
      ?.closest("[data-nested-form-target='row']:not(.hidden)")

    if (row && row !== this.dragged) {
      this.moveRelativeTo(row)
      return
    }

    this.reorderByPointer(event.clientY)
  }

  onPointerUp() {
    this.dragged?.classList.remove("opacity-50")
    document.removeEventListener("pointermove", this.onPointerMove)
    document.removeEventListener("pointerup", this.onPointerUp)
    this.dragged = null
    this.updatePositions()
  }

  refresh() {
    this.updatePositions()
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
      const mid = row.getBoundingClientRect().top + row.getBoundingClientRect().height / 2
      if (clientY < mid) {
        row.before(this.dragged)
        return
      }
    }

    const last = rows[rows.length - 1]
    if (last) last.after(this.dragged)
  }

  rows() {
    return [...this.listTarget.querySelectorAll("[data-nested-form-target='row']:not(.hidden)")]
  }

  updatePositions() {
    this.rows().forEach((row, index) => {
      const input = row.querySelector("input[name*='[position]']")
      if (input) input.value = index
    })
  }
}
