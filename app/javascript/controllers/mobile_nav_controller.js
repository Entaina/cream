import { Controller } from "@hotwired/stimulus"

// Off-canvas sidebar on mobile: hamburger opens drawer, backdrop/Escape closes it.
export default class extends Controller {
  static targets = ["sidebar", "backdrop"]

  connect() {
    this.onKeyDown = this.onKeyDown.bind(this)
    this.onTurboLoad = this.onTurboLoad.bind(this)

    document.addEventListener("keydown", this.onKeyDown)
    document.addEventListener("turbo:load", this.onTurboLoad)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeyDown)
    document.removeEventListener("turbo:load", this.onTurboLoad)
    this.unlockBodyScroll()
  }

  open() {
    if (!this.hasSidebarTarget) return

    this.sidebarTarget.classList.remove("-translate-x-full")
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
    }
    this.lockBodyScroll()
  }

  close() {
    if (!this.hasSidebarTarget) return

    this.sidebarTarget.classList.add("-translate-x-full")
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }
    this.unlockBodyScroll()
  }

  toggle() {
    if (this.isOpen()) this.close()
    else this.open()
  }

  isOpen() {
    return this.hasSidebarTarget && !this.sidebarTarget.classList.contains("-translate-x-full")
  }

  onKeyDown(event) {
    if (event.key === "Escape" && this.isOpen()) {
      this.close()
    }
  }

  onTurboLoad() {
    this.close()
  }

  lockBodyScroll() {
    document.body.classList.add("overflow-hidden")
  }

  unlockBodyScroll() {
    document.body.classList.remove("overflow-hidden")
  }
}
