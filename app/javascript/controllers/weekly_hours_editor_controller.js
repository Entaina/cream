import { Controller } from "@hotwired/stimulus"

const WEEKDAYS = [
  { key: "monday", label: "Lun" },
  { key: "tuesday", label: "Mar" },
  { key: "wednesday", label: "Mié" },
  { key: "thursday", label: "Jue" },
  { key: "friday", label: "Vie" },
  { key: "saturday", label: "Sáb" },
  { key: "sunday", label: "Dom" }
]

const DEFAULT_WINDOW = [ "10:00", "14:00" ]

export default class extends Controller {
  static targets = [ "input", "list" ]
  static values = { defaultSchedule: Object }

  connect() {
    this.schedule = this.parseSchedule(this.inputTarget.value)
    this.render()
  }

  addWindow(event) {
    event.preventDefault()
    event.stopPropagation()
    const day = event.currentTarget.dataset.day
    this.schedule[day].push([ ...DEFAULT_WINDOW ])
    this.render()
  }

  removeWindow(event) {
    event.preventDefault()
    event.stopPropagation()
    const { day, index } = event.currentTarget.dataset
    this.schedule[day].splice(Number(index), 1)
    this.render()
  }

  updateWindow(event) {
    const { day, index, field } = event.target.dataset
    if (!day || index == null || !field) return

    this.schedule[day][Number(index)][field === "start" ? 0 : 1] = event.target.value
    this.sync()
  }

  resetToDefault(event) {
    event.preventDefault()
    const fallback = Object.keys(this.defaultScheduleValue || {}).length
      ? this.defaultScheduleValue
      : null
    this.schedule = fallback
      ? this.parseSchedule(JSON.stringify(fallback))
      : this.defaultSchedule()
    this.render()
  }

  render() {
    this.listTarget.innerHTML = WEEKDAYS.map((day) => this.dayHtml(day)).join("")
    this.sync()
  }

  dayHtml(day) {
    const windows = this.schedule[day.key] || []
    const windowsHtml = windows.length
      ? windows.map((window, index) => this.windowHtml(day.key, window, index)).join("")
      : `<span class="text-xs text-ink-faint">No disponible</span>`

    return `
      <div class="flex flex-wrap items-center gap-x-2 gap-y-1 py-1.5 border-b border-line last:border-b-0">
        <span class="text-sm font-medium w-24 shrink-0">${day.label}</span>
        <div class="flex flex-wrap items-center gap-1 flex-1 min-w-0">
          ${windowsHtml}
        </div>
        <button type="button"
                class="btn-ghost text-xs py-0.5 px-1.5 shrink-0"
                data-day="${day.key}"
                data-action="weekly-hours-editor#addWindow">
          +
        </button>
      </div>
    `
  }

  windowHtml(day, window, index) {
    const [ start, end ] = window
    return `
      <span class="inline-flex items-center gap-0.5 rounded-md bg-canvas-sunken px-1 py-0.5">
        <input type="time"
               value="${start}"
               class="input w-[5.5rem] py-0.5 text-xs"
               data-day="${day}"
               data-index="${index}"
               data-field="start"
               data-action="change->weekly-hours-editor#updateWindow input->weekly-hours-editor#updateWindow click->weekly-hours-editor#stopClick">
        <span class="text-ink-faint text-xs">–</span>
        <input type="time"
               value="${end}"
               class="input w-[5.5rem] py-0.5 text-xs"
               data-day="${day}"
               data-index="${index}"
               data-field="end"
               data-action="change->weekly-hours-editor#updateWindow input->weekly-hours-editor#updateWindow click->weekly-hours-editor#stopClick">
        <button type="button"
                class="btn-ghost text-danger p-0.5 text-xs leading-none"
                title="Quitar franja"
                data-day="${day}"
                data-index="${index}"
                data-action="weekly-hours-editor#removeWindow">
          ✕
        </button>
      </span>
    `
  }

  stopClick(event) {
    event.stopPropagation()
  }

  parseSchedule(raw) {
    try {
      const data = JSON.parse(raw || "{}")
      return WEEKDAYS.reduce((schedule, day) => {
        schedule[day.key] = Array.isArray(data[day.key])
          ? data[day.key].map((window) => [ String(window[0]), String(window[1]) ])
          : []
        return schedule
      }, {})
    } catch (_error) {
      return this.defaultSchedule()
    }
  }

  defaultSchedule() {
    return WEEKDAYS.reduce((schedule, day) => {
      schedule[day.key] = []
      return schedule
    }, {})
  }

  sync() {
    this.inputTarget.value = JSON.stringify(this.schedule)
  }
}
