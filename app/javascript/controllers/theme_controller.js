import { Controller } from "@hotwired/stimulus"

const THEMES = ["light", "dark", "system"]

// Cycles the color theme (light → dark → system), applies it instantly on
// <html data-theme> and persists it to the user preference.
export default class extends Controller {
  static targets = ["option"]
  static values = { url: String, theme: String, copy: Object }

  connect() {
    this.render()
  }

  async cycle() {
    const index = THEMES.indexOf(this.themeValue)
    this.themeValue = THEMES[(index + 1) % THEMES.length]
    document.documentElement.dataset.theme = this.themeValue
    this.render()

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ theme: this.themeValue })
      })

      if (!response.ok) {
        console.error("Failed to save theme preference", response.status)
      }
    } catch (error) {
      console.error("Failed to save theme preference", error)
    }
  }

  render() {
    this.optionTargets.forEach((option) => {
      option.classList.toggle("hidden", option.dataset.theme !== this.themeValue)
    })
    this.element.title = (this.copyValue || {})[this.themeValue] || this.themeValue
  }
}
