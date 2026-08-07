import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "link"]
  static values = { urlTemplate: String }

  connect() {
    this.update()
  }

  update() {
    const id = this.selectTarget.value

    if (id) {
      this.linkTarget.href = this.urlTemplateValue.replace("__ID__", id)
      this.linkTarget.classList.remove("invisible", "pointer-events-none")
      this.linkTarget.removeAttribute("tabindex")
    } else {
      this.linkTarget.removeAttribute("href")
      this.linkTarget.classList.add("invisible", "pointer-events-none")
      this.linkTarget.setAttribute("tabindex", "-1")
    }
  }
}
