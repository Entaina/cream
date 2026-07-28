import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "copyIcon", "copiedIcon", "feedback"]

  async copy() {
    const text = (this.sourceTarget.value ?? this.sourceTarget.textContent).trim()
    if (!text) return

    try {
      await navigator.clipboard.writeText(text)
    } catch {
      this.sourceTarget.focus()
      this.sourceTarget.select()
      document.execCommand("copy")
    }

    this.showCopied()
  }

  showCopied() {
    if (this.hasCopyIconTarget) this.copyIconTarget.classList.add("hidden")
    if (this.hasCopiedIconTarget) this.copiedIconTarget.classList.remove("hidden")
    if (this.hasFeedbackTarget) this.feedbackTarget.classList.remove("hidden")
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.add("text-green-600", "dark:text-green-400")
    }

    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => this.reset(), 2000)
  }

  reset() {
    if (this.hasCopyIconTarget) this.copyIconTarget.classList.remove("hidden")
    if (this.hasCopiedIconTarget) this.copiedIconTarget.classList.add("hidden")
    if (this.hasFeedbackTarget) this.feedbackTarget.classList.add("hidden")
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("text-green-600", "dark:text-green-400")
    }
  }

  disconnect() {
    clearTimeout(this.resetTimeout)
  }
}
