import { Controller } from "@hotwired/stimulus"

// Generic searchable combobox for record pickers (companies, people, etc.).
// Filters inline when records are embedded; otherwise queries searchUrl with debounce.
// Optionally creates a new record on the fly via createUrl.
export default class extends Controller {
  static targets = ["input", "hidden", "menu", "error"]
  static values = {
    searchUrl: String,
    createUrl: String,
    createParam: String,
    records: { type: Array, default: [] }
  }

  connect() {
    this.activeIndex = -1
    this.results = []
    this.inlineRecords = this.hasRecordsValue ? [ ...this.recordsValue ] : null
    this.onMenuMouseDown = (event) => event.preventDefault()
    this.menuTarget.addEventListener("mousedown", this.onMenuMouseDown)
  }

  disconnect() {
    this.menuTarget.removeEventListener("mousedown", this.onMenuMouseDown)
    clearTimeout(this.debounce)
  }

  get inlineMode() {
    return this.inlineRecords !== null
  }

  get createEnabled() {
    return this.hasCreateUrlValue && this.createUrlValue.length > 0
  }

  query() {
    this.clearError()
    this.hiddenTarget.value = ""
    this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))

    const q = this.inputTarget.value.trim()
    if (q.length === 0) {
      this.hideMenu()
      return
    }

    if (this.inlineMode) {
      this.results = this.filterInline(q)
      this.renderMenu(q)
      return
    }

    if (q.length < 2) {
      this.hideMenu()
      return
    }

    clearTimeout(this.debounce)
    this.debounce = setTimeout(async () => {
      const response = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(q)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return

      this.results = await response.json()
      this.renderMenu(q)
    }, 200)
  }

  focus() {
    const q = this.inputTarget.value.trim()
    if (q.length === 0) return
    this.query()
  }

  filterInline(q) {
    const needle = this.normalize(q)
    return this.inlineRecords
      .filter((record) => {
        const haystack = [ record.name, record.hint ].filter(Boolean).map((part) => this.normalize(part)).join(" ")
        return haystack.includes(needle)
      })
      .slice(0, 10)
  }

  renderMenu(query) {
    const items = []
    const exactMatch = this.results.some((record) => this.normalize(record.name) === this.normalize(query))

    this.results.forEach((record, index) => {
      items.push(this.resultItem(record, index))
    })

    if (this.createEnabled && query.length > 0 && !exactMatch) {
      items.push(this.createItem(query, items.length))
    }

    if (items.length === 0) {
      this.menuTarget.innerHTML = `<li class="px-3 py-1.5 text-sm text-ink-faint">No results</li>`
      this.menuTarget.classList.remove("hidden")
      this.activeIndex = -1
      return
    }

    this.activeIndex = -1
    this.menuTarget.innerHTML = items.join("")
    this.menuTarget.classList.remove("hidden")
  }

  resultItem(record, index) {
    const hint = record.hint ? `<span class="text-ink-faint"> · ${this.escape(record.hint)}</span>` : ""
    return `<li role="option" data-index="${index}" data-action="click->record-picker#pick"
                class="cursor-pointer px-3 py-1.5 text-sm hover:bg-canvas-sunken">
              <span class="font-medium">${this.escape(record.name)}</span>${hint}
            </li>`
  }

  createItem(query, index) {
    return `<li role="option" data-create="true" data-index="${index}" data-action="click->record-picker#createPick"
                class="cursor-pointer px-3 py-1.5 text-sm text-accent hover:bg-canvas-sunken">
              <span class="font-medium">+ Create "${this.escape(query)}"</span>
            </li>`
  }

  pick(event) {
    const record = this.results[Number(event.currentTarget.dataset.index)]
    if (!record) return
    this.selectRecord(record)
  }

  async createPick(event) {
    event.preventDefault()
    const query = this.inputTarget.value.trim()
    if (!query || !this.createEnabled) return

    this.clearError()
    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ [this.createParamValue]: { name: query } })
      })

      if (!response.ok) {
        const data = await response.json().catch(() => ({}))
        this.showError((data.errors || ["Could not create"]).join(", "))
        return
      }

      const record = await response.json()
      if (this.inlineMode) this.inlineRecords.push({ id: record.id, name: record.name, hint: record.hint || null })
      this.selectRecord(record)
    } catch {
      this.showError("Network error, please try again")
    }
  }

  selectRecord(record) {
    this.hiddenTarget.value = record.id
    this.inputTarget.value = record.name
    this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    // Custom event for consumers that must ignore the clear-on-keystroke change.
    this.dispatch("selected", { detail: { id: record.id, name: record.name } })
    this.hideMenu()
  }

  keydown(event) {
    const options = this.menuOptions()
    if (event.key === "Escape") {
      this.hideMenu()
      event.preventDefault()
      return
    }

    if (this.menuTarget.classList.contains("hidden") || options.length === 0) return

    if (event.key === "ArrowDown") {
      this.activeIndex = Math.min(this.activeIndex + 1, options.length - 1)
      this.highlightOption(options)
      event.preventDefault()
      return
    }

    if (event.key === "ArrowUp") {
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlightOption(options)
      event.preventDefault()
      return
    }

    if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      options[this.activeIndex].click()
    }
  }

  menuOptions() {
    return Array.from(this.menuTarget.querySelectorAll('[role="option"]'))
  }

  highlightOption(options) {
    options.forEach((option, index) => {
      option.classList.toggle("bg-canvas-sunken", index === this.activeIndex)
    })
    options[this.activeIndex]?.scrollIntoView({ block: "nearest" })
  }

  hide() {
    setTimeout(() => this.hideMenu(), 150)
  }

  hideMenu() {
    this.menuTarget.classList.add("hidden")
    this.activeIndex = -1
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  normalize(text) {
    return (text ?? "").normalize("NFD").replace(/\p{M}/gu, "").toLowerCase()
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text ?? ""
    return div.innerHTML
  }
}
