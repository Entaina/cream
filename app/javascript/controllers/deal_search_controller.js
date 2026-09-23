import { Controller } from "@hotwired/stimulus"

// Search-as-you-type deal picker for linking a Stripe payment to a deal.
// Queries /deals/picker.json (open + won deals) and fills a hidden deal_id.
export default class extends Controller {
  static targets = ["input", "hidden", "menu", "submit"]
  static values = { url: String, empty: String }

  connect() {
    this.activeIndex = -1
    this.results = []
    this.onMenuMouseDown = (event) => event.preventDefault() // keep input focus
    this.menuTarget.addEventListener("mousedown", this.onMenuMouseDown)
  }

  disconnect() {
    this.menuTarget.removeEventListener("mousedown", this.onMenuMouseDown)
    clearTimeout(this.debounce)
  }

  query() {
    this.hiddenTarget.value = ""
    this.submitTarget.disabled = true
    clearTimeout(this.debounce)
    const q = this.inputTarget.value.trim()
    if (q.length < 2) { this.hideMenu(); return }

    this.debounce = setTimeout(async () => {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return

      this.results = await response.json()
      this.renderMenu()
    }, 200)
  }

  renderMenu() {
    if (this.results.length === 0) {
      this.menuTarget.innerHTML = `<li class="px-3 py-1.5 text-sm text-ink-faint">${this.escape(this.emptyValue)}</li>`
      this.menuTarget.classList.remove("hidden")
      return
    }

    this.activeIndex = -1
    this.menuTarget.innerHTML = this.results.map((deal, index) => `
      <li role="option" data-index="${index}" data-action="click->deal-search#pick"
          class="cursor-pointer px-3 py-1.5 text-sm hover:bg-canvas-sunken">
        <span class="font-medium">${this.escape(deal.name)}</span>
        <span class="text-ink-faint">${this.escape([deal.company, deal.stage, deal.value].filter(Boolean).join(" · "))}</span>
      </li>`).join("")
    this.menuTarget.classList.remove("hidden")
  }

  pick(event) {
    const deal = this.results[Number(event.currentTarget.dataset.index)]
    if (!deal) return

    this.hiddenTarget.value = deal.id
    this.inputTarget.value = deal.name
    this.submitTarget.disabled = false
    this.hideMenu()
  }

  keydown(event) {
    if (this.menuTarget.classList.contains("hidden")) return

    if (event.key === "Escape") { this.hideMenu(); event.preventDefault() }
    if (event.key === "Enter" && this.hiddenTarget.value === "") event.preventDefault()
  }

  hide() {
    setTimeout(() => this.hideMenu(), 150)
  }

  hideMenu() {
    this.menuTarget.classList.add("hidden")
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text ?? ""
    return div.innerHTML
  }
}
