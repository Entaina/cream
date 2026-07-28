import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("close", this.remove)
    this.element.showModal()
  }

  disconnect() {
    this.element.removeEventListener("close", this.remove)
  }

  close() {
    this.element.close()
  }

  remove = () => {
    this.element.remove()
  }
}
