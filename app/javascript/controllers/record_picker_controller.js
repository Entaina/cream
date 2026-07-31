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
    records: Array
  }

  connect() {
    this.activeIndex = -1
    this.results = []
    this.loadInlineRecords()
    this.menuEl = this.menuTarget
    this.menuPortaled = false
    this.menuAnchor = document.createComment("record-picker-menu")
    this.onMenuMouseDown = (event) => event.preventDefault()
    this.onMenuClick = (event) => this.handleMenuClick(event)
    this.boundRepositionMenu = this.repositionMenu.bind(this)
    this.boundOnScroll = this.onScroll.bind(this)
    this.menuEl.addEventListener("mousedown", this.onMenuMouseDown)
    this.menuEl.addEventListener("click", this.onMenuClick)
  }

  disconnect() {
    this.menuEl.removeEventListener("mousedown", this.onMenuMouseDown)
    this.menuEl.removeEventListener("click", this.onMenuClick)
    clearTimeout(this.debounce)
    this.removeMenuListeners()
    if (this.menuPortaled) {
      this.menuEl.remove()
      this.menuAnchor.remove()
    }
  }

  get inlineMode() {
    return Array.isArray(this.inlineRecords) && this.inlineRecords.length > 0
  }

  loadInlineRecords() {
    if (this.hasRecordsValue && this.recordsValue.length > 0) {
      this.inlineRecords = [ ...this.recordsValue ]
    } else {
      this.inlineRecords = null
    }
  }

  setInlineRecords(records) {
    this.inlineRecords = records.length > 0 ? records : null
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

    if (!this.searchUrlValue || q.length < 1) {
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
      this.menuEl.innerHTML = `<li class="px-3 py-1.5 text-sm text-ink-faint">No results</li>`
      this.openMenu()
      this.activeIndex = -1
      return
    }

    this.activeIndex = -1
    this.menuEl.innerHTML = items.join("")
    this.openMenu()
  }

  openMenu() {
    this.portalMenu()
    this.repositionMenu()
    this.menuEl.classList.remove("hidden")
  }

  portalMenu() {
    if (this.menuPortaled) return

    this.menuEl.parentNode.insertBefore(this.menuAnchor, this.menuEl)
    document.body.appendChild(this.menuEl)
    this.menuPortaled = true
    window.addEventListener("scroll", this.boundOnScroll, true)
    window.addEventListener("resize", this.boundRepositionMenu)
  }

  unportalMenu() {
    if (!this.menuPortaled) return

    this.removeMenuListeners()
    this.menuAnchor.parentNode?.insertBefore(this.menuEl, this.menuAnchor)
    this.menuAnchor.remove()
    this.resetMenuStyles()
    this.menuPortaled = false
  }

  removeMenuListeners() {
    window.removeEventListener("scroll", this.boundOnScroll, true)
    window.removeEventListener("resize", this.boundRepositionMenu)
  }

  repositionMenu() {
    const rect = this.inputTarget.getBoundingClientRect()
    const menu = this.menuEl

    menu.style.position = "fixed"
    menu.style.top = `${rect.bottom + 4}px`
    menu.style.left = `${rect.left}px`
    menu.style.width = `${rect.width}px`
    menu.style.zIndex = "9999"
  }

  onScroll() {
    if (this.menuEl.classList.contains("hidden")) return
    this.repositionMenu()
  }

  resetMenuStyles() {
    this.menuEl.style.position = ""
    this.menuEl.style.top = ""
    this.menuEl.style.left = ""
    this.menuEl.style.width = ""
    this.menuEl.style.zIndex = ""
  }

  handleMenuClick(event) {
    const option = event.target.closest('[role="option"]')
    if (!option) return

    event.preventDefault()
    if (option.dataset.create === "true") {
      this.createPick(event)
      return
    }

    this.pick({ currentTarget: option })
  }

  resultItem(record, index) {
    const hint = record.hint ? `<span class="text-ink-faint"> · ${this.escape(record.hint)}</span>` : ""
    return `<li role="option" data-index="${index}"
                class="cursor-pointer px-3 py-1.5 text-sm hover:bg-canvas-sunken">
              <span class="font-medium">${this.escape(record.name)}</span>${hint}
            </li>`
  }

  createItem(query, index) {
    return `<li role="option" data-create="true" data-index="${index}"
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

    if (this.menuEl.classList.contains("hidden") || options.length === 0) return

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
    return Array.from(this.menuEl.querySelectorAll('[role="option"]'))
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
    this.menuEl.classList.add("hidden")
    this.activeIndex = -1
    this.unportalMenu()
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  clear() {
    this.inputTarget.value = ""
    this.hiddenTarget.value = ""
    this.hideMenu()
    this.clearError()
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
