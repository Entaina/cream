import { Controller } from "@hotwired/stimulus"

const GRIP_ICON = `<svg class="size-3.5 pointer-events-none" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><circle cx="5" cy="4" r="1.2"/><circle cx="11" cy="4" r="1.2"/><circle cx="5" cy="8" r="1.2"/><circle cx="11" cy="8" r="1.2"/><circle cx="5" cy="12" r="1.2"/><circle cx="11" cy="12" r="1.2"/></svg>`

export default class extends Controller {
  static targets = [
    "hostSelect", "calendarList", "calendarHint", "calendarError",
    "calendarRow", "calendarIdsInputs", "eventCalendarBadge"
  ]
  static values = {
    calendarsUrl: String,
    selectedIds: Array,
    calendars: Array,
    calendarsError: String,
    hostConnected: Boolean,
    i18n: Object
  }

  connect() {
    this.onCalendarPointerMove = this.onCalendarPointerMove.bind(this)
    this.onCalendarPointerUp = this.onCalendarPointerUp.bind(this)

    if (this.calendarsErrorValue) {
      this.renderUnavailable("load_failed", this.calendarsErrorValue)
      return
    }

    if (!this.hostConnectedValue && !this.calendarsValue?.length) {
      this.renderUnavailable("not_connected")
      return
    }

    this.renderCalendars(this.calendarsValue, this.selectedIdsValue)
  }

  disconnect() {
    this.endCalendarDrag()
  }

  hostChanged() {
    const hostId = this.hostSelectTarget.value
    if (!hostId) return

    this.calendarListTarget.innerHTML = `<p class="text-sm text-ink-faint">${this.escape(this.t("loading_calendars"))}</p>`
    this.clearCalendarIdsInputs()
    this.hideError()

    fetch(`${this.calendarsUrlValue}?host_id=${encodeURIComponent(hostId)}`, {
      headers: { Accept: "application/json" }
    })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        if (!ok) {
          if (body.error === "insufficient_scopes") {
            this.renderUnavailable("insufficient_scopes", body.message)
          } else if (body.message) {
            this.renderUnavailable(body.error || "load_failed", body.message, body.help_url)
          } else {
            this.renderUnavailable(body.error)
          }
          return
        }

        const selected = this.defaultSelectedIds(body.calendars)
        this.renderCalendars(body.calendars, selected)
      })
      .catch(() => {
        this.renderUnavailable("load_failed")
      })
  }

  renderCalendars(calendars, selectedIds) {
    if (!calendars?.length) {
      if (this.hostConnectedValue) {
        this.renderUnavailable("load_failed", this.t("no_calendars_found"))
      } else {
        this.renderUnavailable("not_connected")
      }
      return
    }

    this.hideError()
    const selected = new Set(selectedIds || [])
    const ordered = this.orderCalendars(calendars, selectedIds)
    const items = ordered.map((calendar) => this.calendarRowHtml(calendar, selected.has(calendar.id))).join("")

    this.calendarListTarget.innerHTML = `<div class="space-y-2">${items}</div>`
    this.syncCalendarIds()
    this.updateEventCalendarBadges()
    this.calendarHintTarget.classList.remove("hidden")
  }

  calendarRowHtml(calendar, checked) {
    const primary = calendar.primary ? `<span class="text-xs text-ink-faint">${this.escape(this.t("calendar_primary"))}</span>` : ""
    const access = calendar.writable
      ? `<span class="text-xs text-ink-faint">${this.escape(this.t("calendar_writable"))}</span>`
      : `<span class="text-xs text-ink-faint">${this.escape(this.t("calendar_readonly"))}</span>`

    return `
      <div class="flex items-start gap-2 rounded-md border border-line px-2 py-2 hover:bg-canvas-sunken bg-canvas-raised"
           data-booking-page-form-target="calendarRow"
           data-calendar-id="${this.escape(calendar.id)}"
           data-calendar-writable="${calendar.writable ? "true" : "false"}">
        <span role="button" tabindex="-1"
              class="cursor-grab active:cursor-grabbing text-ink-faint hover:text-ink-soft p-1.5 touch-none select-none shrink-0 mt-0.5"
              title="${this.escape(this.t("calendar_drag_title"))}"
              aria-label="${this.escape(this.t("calendar_drag_aria"))}"
              data-action="pointerdown->booking-page-form#calendarDragStart">
          ${GRIP_ICON}
        </span>
        <label class="flex flex-1 items-start gap-2 min-w-0 cursor-pointer">
          <input type="checkbox"
                 class="mt-0.5 shrink-0"
                 ${checked ? "checked" : ""}
                 data-action="change->booking-page-form#calendarSelectionChanged">
          <span class="min-w-0">
            <span class="font-medium">${this.escape(calendar.summary)}</span>
            ${primary}
            ${access}
            <span data-booking-page-form-target="eventCalendarBadge"
                  class="hidden ml-1 inline-flex items-center rounded-full bg-green-100 px-1.5 py-0.5 text-xs font-medium text-green-800 ring-1 ring-inset ring-green-200 dark:bg-green-900 dark:text-green-200 dark:ring-green-800">
              ${this.escape(this.t("event_calendar_badge"))}
            </span>
          </span>
        </label>
      </div>
    `
  }

  calendarSelectionChanged() {
    this.syncCalendarIds()
    this.updateEventCalendarBadges()
  }

  calendarDragStart(event) {
    if (event.button !== 0) return

    this.draggedCalendarRow = event.target.closest("[data-booking-page-form-target='calendarRow']")
    if (!this.draggedCalendarRow) return

    event.preventDefault()
    this.draggedCalendarRow.classList.add("opacity-50")
    document.addEventListener("pointermove", this.onCalendarPointerMove)
    document.addEventListener("pointerup", this.onCalendarPointerUp)
  }

  onCalendarPointerMove(event) {
    if (!this.draggedCalendarRow) return

    const row = document.elementFromPoint(event.clientX, event.clientY)
      ?.closest("[data-booking-page-form-target='calendarRow']")

    if (row && row !== this.draggedCalendarRow) {
      this.moveCalendarRelativeTo(row)
      return
    }

    this.reorderCalendarByPointer(event.clientY)
  }

  onCalendarPointerUp() {
    this.endCalendarDrag()
    this.syncCalendarIds()
    this.updateEventCalendarBadges()
  }

  endCalendarDrag() {
    this.draggedCalendarRow?.classList.remove("opacity-50")
    document.removeEventListener("pointermove", this.onCalendarPointerMove)
    document.removeEventListener("pointerup", this.onCalendarPointerUp)
    this.draggedCalendarRow = null
  }

  moveCalendarRelativeTo(targetRow) {
    const rows = this.calendarRows()
    const draggedIndex = rows.indexOf(this.draggedCalendarRow)
    const targetIndex = rows.indexOf(targetRow)
    if (draggedIndex === -1 || targetIndex === -1) return

    if (draggedIndex < targetIndex) {
      targetRow.after(this.draggedCalendarRow)
    } else {
      targetRow.before(this.draggedCalendarRow)
    }
  }

  reorderCalendarByPointer(clientY) {
    const rows = this.calendarRows().filter((row) => row !== this.draggedCalendarRow)
    for (const row of rows) {
      const mid = row.getBoundingClientRect().top + row.getBoundingClientRect().height / 2
      if (clientY < mid) {
        row.before(this.draggedCalendarRow)
        return
      }
    }

    const last = rows[rows.length - 1]
    if (last) last.after(this.draggedCalendarRow)
  }

  calendarRows() {
    return this.calendarRowTargets
  }

  syncCalendarIds() {
    if (!this.hasCalendarIdsInputsTarget) return

    const selectedRows = this.calendarRowTargets.filter((row) =>
      row.querySelector('input[type="checkbox"]')?.checked
    )

    this.calendarIdsInputsTarget.innerHTML = selectedRows.map((row) =>
      `<input type="hidden" name="booking_page[calendar_ids][]" value="${this.escape(row.dataset.calendarId)}">`
    ).join("")
  }

  updateEventCalendarBadges() {
    let eventCalendarAssigned = false

    this.calendarRowTargets.forEach((row) => {
      const badge = row.querySelector("[data-booking-page-form-target='eventCalendarBadge']")
      if (!badge) return

      const checked = row.querySelector('input[type="checkbox"]')?.checked
      const writable = row.dataset.calendarWritable === "true"

      if (!eventCalendarAssigned && checked && writable) {
        badge.classList.remove("hidden")
        eventCalendarAssigned = true
      } else {
        badge.classList.add("hidden")
      }
    })
  }

  orderCalendars(calendars, selectedIds) {
    const ids = selectedIds || []
    const byId = new Map(calendars.map((calendar) => [ calendar.id, calendar ]))
    const ordered = ids.map((id) => byId.get(id)).filter(Boolean)
    const selectedSet = new Set(ids)

    calendars.forEach((calendar) => {
      if (!selectedSet.has(calendar.id)) ordered.push(calendar)
    })

    return ordered
  }

  renderUnavailable(errorKey, customMessage = null, helpUrl = null) {
    this.calendarListTarget.innerHTML = ""
    this.clearCalendarIdsInputs()
    this.calendarHintTarget.classList.add("hidden")

    const defaults = {
      not_connected: this.t("not_connected"),
      insufficient_scopes: this.t("insufficient_scopes"),
      load_failed: this.t("load_failed"),
      api_disabled: this.t("api_disabled")
    }

    const message = customMessage || defaults[errorKey] || this.t("load_failed")

    const helpLink = helpUrl
      ? ` <a href="${this.escape(helpUrl)}" class="text-accent hover:underline" target="_blank" rel="noopener">${this.escape(this.t("activate_api_link"))}</a>`
      : ""

    this.calendarErrorTarget.innerHTML = `${this.escape(message)}${helpLink}`
    this.calendarErrorTarget.classList.remove("hidden")
  }

  defaultSelectedIds(calendars) {
    const primary = calendars.find((calendar) => calendar.primary)
    return [ primary?.id || calendars[0]?.id ].filter(Boolean)
  }

  clearCalendarIdsInputs() {
    if (this.hasCalendarIdsInputsTarget) {
      this.calendarIdsInputsTarget.innerHTML = ""
    }
  }

  hideError() {
    this.calendarErrorTarget.textContent = ""
    this.calendarErrorTarget.classList.add("hidden")
  }

  t(key) {
    return this.i18nValue?.[key] || key
  }

  escape(text) {
    return String(text || "").replace(/[&<>"']/g, (char) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[char])
  }
}
