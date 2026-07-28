import { Controller } from "@hotwired/stimulus"

// Searchable multi-select for the merge contacts screen.
// Adds picked people as checked secondary_ids[] rows in the merge form.
export default class extends Controller {
  static targets = ["input", "menu", "list", "submit"]
  static values = {
    searchUrl: String,
    excludeId: Number
  }

  connect() {
    this.activeIndex = -1
    this.results = []
    this.onMenuMouseDown = (event) => event.preventDefault()
    this.menuTarget.addEventListener("mousedown", this.onMenuMouseDown)
    this.updateSubmitState()
  }

  disconnect() {
    this.menuTarget.removeEventListener("mousedown", this.onMenuMouseDown)
    clearTimeout(this.debounce)
  }

  query() {
    const q = this.inputTarget.value.trim()
    if (q.length === 0) {
      this.hideMenu()
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

      const allResults = await response.json()
      this.results = allResults.filter((record) => {
        if (record.id === this.excludeIdValue) return false
        return !this.hasPerson(record.id)
      })
      this.renderMenu()
    }, 200)
  }

  focus() {
    const q = this.inputTarget.value.trim()
    if (q.length === 0) return
    this.query()
  }

  pick(event) {
    const record = this.results[Number(event.currentTarget.dataset.index)]
    if (!record) return

    const existing = this.listTarget.querySelector(`[data-person-id="${record.id}"] input[type="checkbox"]`)
    if (existing) {
      existing.checked = true
    } else {
      this.addPerson(record, true)
    }

    this.inputTarget.value = ""
    this.hideMenu()
    this.updateSubmitState()
  }

  addPerson(record, checked) {
    const label = document.createElement("label")
    label.className = "flex items-start gap-3 rounded-lg border border-line px-3 py-2.5 hover:bg-canvas-sunken cursor-pointer"
    label.dataset.mergePersonSearchTarget = "row"
    label.dataset.personId = String(record.id)

    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.name = "secondary_ids[]"
    checkbox.value = record.id
    checkbox.checked = checked
    checkbox.className = "mt-1 rounded border-line text-accent focus:ring-accent"
    checkbox.dataset.action = "change->merge-person-search#updateSubmitState"

    const text = document.createElement("span")
    text.className = "min-w-0"

    const name = document.createElement("span")
    name.className = "font-medium block"
    name.textContent = record.name
    text.appendChild(name)

    if (record.hint) {
      const hint = document.createElement("span")
      hint.className = "text-sm text-ink-faint block"
      hint.textContent = record.hint
      text.appendChild(hint)
    }

    label.appendChild(checkbox)
    label.appendChild(text)
    this.listTarget.appendChild(label)
  }

  hasPerson(id) {
    return this.listTarget.querySelector(`[data-person-id="${id}"]`) !== null
  }

  updateSubmitState() {
    if (!this.hasSubmitTarget) return

    const anyChecked = this.listTarget.querySelectorAll('input[type="checkbox"]:checked').length > 0
    this.submitTarget.disabled = !anyChecked
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

  renderMenu() {
    if (this.results.length === 0) {
      this.menuTarget.innerHTML = `<li class="px-3 py-1.5 text-sm text-ink-faint">No results</li>`
      this.menuTarget.classList.remove("hidden")
      this.activeIndex = -1
      return
    }

    this.activeIndex = -1
    this.menuTarget.innerHTML = this.results.map((record, index) => this.resultItem(record, index)).join("")
    this.menuTarget.classList.remove("hidden")
  }

  resultItem(record, index) {
    const hint = record.hint ? `<span class="text-ink-faint"> · ${this.escape(record.hint)}</span>` : ""
    return `<li role="option" data-index="${index}" data-action="click->merge-person-search#pick"
                class="cursor-pointer px-3 py-1.5 text-sm hover:bg-canvas-sunken">
              <span class="font-medium">${this.escape(record.name)}</span>${hint}
            </li>`
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

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text ?? ""
    return div.innerHTML
  }
}
