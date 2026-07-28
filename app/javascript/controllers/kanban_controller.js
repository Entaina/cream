import { Controller } from "@hotwired/stimulus"

// Kanban board: drag deals between columns and reorder columns by their headers.
export default class extends Controller {
  static targets = ["column", "card", "stageColumn", "stageTrack", "columnHandle"]
  static values = { url: String, reorderUrl: String }

  connect() {
    this.onDragStart = this.onDragStart.bind(this)
    this.onDragEnd = this.onDragEnd.bind(this)
    this.onDragOver = this.onDragOver.bind(this)
    this.onDragLeave = this.onDragLeave.bind(this)
    this.onDrop = this.onDrop.bind(this)
    this.onColumnPointerMove = this.onColumnPointerMove.bind(this)
    this.onColumnPointerUp = this.onColumnPointerUp.bind(this)
    this.onColumnPointerCancel = this.onColumnPointerCancel.bind(this)

    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragend", this.onDragEnd)
    this.element.addEventListener("dragover", this.onDragOver)
    this.element.addEventListener("dragleave", this.onDragLeave)
    this.element.addEventListener("drop", this.onDrop)
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragend", this.onDragEnd)
    this.element.removeEventListener("dragover", this.onDragOver)
    this.element.removeEventListener("dragleave", this.onDragLeave)
    this.element.removeEventListener("drop", this.onDrop)
    this.stopColumnDragListeners()
  }

  columnPointerDown(event) {
    if (event.button !== 0 || !this.hasReorderUrlValue) return
    if (this.draggedColumn) return

    this.draggedColumn = event.target.closest("[data-kanban-target='stageColumn']")
    if (!this.draggedColumn) return

    event.preventDefault()

    this.originalColumnOrder = this.orderedColumns().map(column => column.dataset.stageId)

    const rect = this.draggedColumn.getBoundingClientRect()
    this.columnDragOffsetX = event.clientX - rect.left
    this.columnDragOffsetY = event.clientY - rect.top

    this.columnGhost = this.draggedColumn.cloneNode(true)
    this.columnGhost.querySelectorAll("[id]").forEach(el => el.removeAttribute("id"))
    this.columnGhost.querySelectorAll("[draggable]").forEach(el => el.removeAttribute("draggable"))
    Object.assign(this.columnGhost.style, {
      position: "fixed",
      zIndex: "50",
      width: `${rect.width}px`,
      maxHeight: `${Math.min(rect.height, window.innerHeight * 0.65)}px`,
      overflow: "hidden",
      pointerEvents: "none",
      left: "0",
      top: "0"
    })
    this.columnGhost.classList.add("shadow-xl", "ring-2", "ring-accent/30", "scale-[1.02]", "opacity-95")
    document.body.appendChild(this.columnGhost)

    this.columnPlaceholder = document.createElement("div")
    this.columnPlaceholder.className = "w-72 shrink-0 rounded-xl ring-2 ring-dashed ring-accent/50 bg-accent/10"
    this.columnPlaceholder.style.minHeight = `${rect.height}px`
    this.columnPlaceholder.setAttribute("aria-hidden", "true")

    window.addEventListener("pointermove", this.onColumnPointerMove)
    window.addEventListener("pointerup", this.onColumnPointerUp)
    window.addEventListener("pointercancel", this.onColumnPointerCancel)

    this.draggedColumn.replaceWith(this.columnPlaceholder)
    this.positionColumnGhost(event)
  }

  onColumnPointerMove(event) {
    if (!this.draggedColumn || !this.columnPlaceholder) return

    this.positionColumnGhost(event)
    this.moveColumnPlaceholder(event.clientX, event.clientY)
  }

  onColumnPointerUp(event) {
    this.finishColumnDrag({ persist: true, event })
  }

  onColumnPointerCancel(event) {
    this.finishColumnDrag({ persist: false, event })
  }

  stopColumnDragListeners() {
    window.removeEventListener("pointermove", this.onColumnPointerMove)
    window.removeEventListener("pointerup", this.onColumnPointerUp)
    window.removeEventListener("pointercancel", this.onColumnPointerCancel)
  }

  moveColumnPlaceholder(clientX, clientY) {
    const targetColumn = this.columnUnderPointer(clientX, clientY)
    if (!targetColumn) return

    const placeholderIsAfter =
      targetColumn.compareDocumentPosition(this.columnPlaceholder) &
      Node.DOCUMENT_POSITION_FOLLOWING

    if (placeholderIsAfter) {
      targetColumn.before(this.columnPlaceholder)
    } else {
      targetColumn.after(this.columnPlaceholder)
    }
  }

  columnUnderPointer(clientX, clientY) {
    const hit = document.elementFromPoint(clientX, clientY)
    const fromHit = hit?.closest("[data-kanban-target='stageColumn']")
    if (fromHit && this.stageTrackTarget.contains(fromHit)) return fromHit

    for (const column of this.visibleColumns()) {
      const rect = column.getBoundingClientRect()
      if (clientX >= rect.left && clientX <= rect.right &&
          clientY >= rect.top && clientY <= rect.bottom) {
        return column
      }
    }

    return null
  }

  visibleColumns() {
    return [...this.stageTrackTarget.querySelectorAll("[data-kanban-target='stageColumn']")]
  }

  positionColumnGhost(event) {
    if (!this.columnGhost) return

    this.columnGhost.style.transform = `translate(${event.clientX - this.columnDragOffsetX}px, ${event.clientY - this.columnDragOffsetY}px)`
  }

  async finishColumnDrag({ persist }) {
    this.stopColumnDragListeners()

    if (!this.draggedColumn) return

    const originalOrder = this.originalColumnOrder
    let stageIds = originalOrder

    if (persist && this.columnPlaceholder) {
      this.columnPlaceholder.replaceWith(this.draggedColumn)
      stageIds = this.orderedColumns().map(column => column.dataset.stageId)
    } else if (this.columnPlaceholder) {
      this.columnPlaceholder.replaceWith(this.draggedColumn)
      if (originalOrder?.length) this.restoreColumnOrder(originalOrder)
    }

    this.columnGhost?.remove()
    this.columnPlaceholder = null
    this.columnGhost = null
    this.draggedColumn = null
    this.originalColumnOrder = null

    if (!persist || stageIds.join(",") === originalOrder.join(",")) return

    try {
      const response = await fetch(this.reorderUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ stage_ids: stageIds })
      })

      if (!response.ok) {
        this.restoreColumnOrder(originalOrder)
        console.error("Failed to reorder stages", response.status)
      }
    } catch (error) {
      this.restoreColumnOrder(originalOrder)
      console.error("Failed to reorder stages", error)
    }
  }

  orderedColumns() {
    if (!this.hasStageTrackTarget) return this.stageColumnTargets
    return [...this.stageTrackTarget.querySelectorAll("[data-kanban-target='stageColumn']")]
  }

  restoreColumnOrder(originalOrder) {
    if (!this.hasStageTrackTarget || !originalOrder?.length) return

    const columnsById = Object.fromEntries(
      this.stageTrackTarget.querySelectorAll("[data-kanban-target='stageColumn']").map(column => [column.dataset.stageId, column])
    )

    originalOrder.forEach(stageId => {
      const column = columnsById[stageId]
      if (column) this.stageTrackTarget.appendChild(column)
    })
  }

  onDragStart(event) {
    const card = event.target.closest("[data-kanban-target='card']")
    if (!card || this.draggedColumn) {
      event.preventDefault()
      return
    }

    this.dragged = card
    this.draggedOrigin = card.parentElement
    this.draggedNextSibling = card.nextElementSibling
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", card.dataset.dealId)

    const rect = card.getBoundingClientRect()
    const ghost = card.cloneNode(true)
    ghost.style.width = `${rect.width}px`
    ghost.style.position = "absolute"
    ghost.style.top = "-9999px"
    ghost.style.left = "-9999px"
    ghost.classList.add("shadow-lg", "ring-2", "ring-accent/25", "opacity-95", "rotate-1")
    document.body.appendChild(ghost)
    event.dataTransfer.setDragImage(ghost, event.clientX - rect.left, event.clientY - rect.top)
    this.cardDragGhost = ghost

    card.classList.add("opacity-30", "ring-2", "ring-accent/20")
  }

  onDragEnd(event) {
    this.cardDragGhost?.remove()
    this.cardDragGhost = null

    const card = event.target.closest("[data-kanban-target='card']")
    card?.classList.remove("opacity-30", "ring-2", "ring-accent/20")

    this.columnTargets.forEach(column => column.classList.remove("ring-2", "ring-accent/40", "rounded-lg"))
    this.dragged = null
    this.draggedOrigin = null
    this.draggedNextSibling = null
  }

  cardAfterPointer(column, clientY) {
    const cards = [...column.querySelectorAll("[data-kanban-target='card']")]
      .filter(card => card !== this.dragged)

    for (const card of cards) {
      const rect = card.getBoundingClientRect()
      const mid = rect.top + rect.height / 2
      if (clientY < mid) return card
    }

    return null
  }

  restoreCardPosition(card) {
    if (!this.draggedOrigin) return

    if (this.draggedNextSibling && this.draggedNextSibling.parentElement === this.draggedOrigin) {
      this.draggedOrigin.insertBefore(card, this.draggedNextSibling)
    } else {
      this.draggedOrigin.appendChild(card)
    }
  }

  onDragOver(event) {
    const column = event.target.closest("[data-kanban-target='column']")
    if (!column || !this.dragged) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    column.classList.add("ring-2", "ring-accent/40", "rounded-lg")

    const reference = this.cardAfterPointer(column, event.clientY)
    if (reference) column.insertBefore(this.dragged, reference)
    else column.appendChild(this.dragged)
  }

  onDragLeave(event) {
    const column = event.target.closest("[data-kanban-target='column']")
    if (!column || column.contains(event.relatedTarget)) return

    column.classList.remove("ring-2", "ring-accent/40", "rounded-lg")
  }

  async onDrop(event) {
    const column = event.target.closest("[data-kanban-target='column']")
    if (!column) return

    event.preventDefault()
    column.classList.remove("ring-2", "ring-accent/40", "rounded-lg")
    if (!this.dragged) return

    const stageId = column.dataset.stage
    const card = this.dragged
    const dealId = card.dataset.dealId
    const cards = [...column.querySelectorAll("[data-kanban-target='card']")]
    const position = cards.indexOf(card)

    try {
      const response = await fetch(this.urlValue.replace(":id", dealId), {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ pipeline_stage_id: stageId, position })
      })

      if (response.ok) {
        if (window.Turbo) window.Turbo.renderStreamMessage(await response.text())
      } else {
        this.restoreCardPosition(card)
        const contentType = response.headers.get("Content-Type") || ""
        if (window.Turbo && contentType.includes("turbo-stream")) {
          window.Turbo.renderStreamMessage(await response.text())
        }
        console.error("Failed to move deal", response.status)
      }
    } catch (error) {
      this.restoreCardPosition(card)
      console.error("Failed to move deal", error)
    }
  }
}
