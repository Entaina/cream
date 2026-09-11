import { Controller } from "@hotwired/stimulus"

// Switches UI locale (es/en), persists to user preference or guest cookie, then reloads.
export default class extends Controller {
  static targets = ["es", "en"]
  static values = { url: String, locale: String, reload: { type: Boolean, default: true } }

  connect() {
    this.render()
  }

  async setLocale(event) {
    const locale = event.currentTarget.dataset.locale
    if (!locale || locale === this.localeValue) return

    this.localeValue = locale
    document.documentElement.lang = locale
    this.render()

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ locale })
      })

      if (!response.ok) {
        console.error("Failed to save locale preference", response.status)
        return
      }

      if (this.reloadValue) window.location.reload()
    } catch (error) {
      console.error("Failed to save locale preference", error)
    }
  }

  render() {
    if (this.hasEsTarget) this.esTarget.classList.toggle("is-active", this.localeValue === "es")
    if (this.hasEnTarget) this.enTarget.classList.toggle("is-active", this.localeValue === "en")
  }
}
