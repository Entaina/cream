import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "editor" ]

  async connect() {
    try {
      const { createLiquidEditor } = await import("codemirror-liquid-editor")
      this.view = createLiquidEditor(this.editorTarget, {
        doc: this.inputTarget.value,
        onUpdate: (value) => { this.inputTarget.value = value }
      })
    } catch (error) {
      console.error("Liquid editor failed to initialize", error)
      this.showPlainTextarea()
      return
    }

    this.form = this.element.closest("form")
    if (this.form) {
      this.submitHandler = () => this.sync()
      this.form.addEventListener("submit", this.submitHandler)
    }
  }

  disconnect() {
    if (this.form && this.submitHandler) {
      this.form.removeEventListener("submit", this.submitHandler)
    }
    if (this.view) {
      this.view.destroy()
      this.view = null
    }
  }

  sync() {
    if (this.view) {
      this.inputTarget.value = this.view.state.doc.toString()
    }
  }

  showPlainTextarea() {
    this.inputTarget.classList.remove("sr-only")
    this.inputTarget.classList.add("input", "w-full", "resize-y", "font-mono", "text-sm", "border-0", "rounded-none")
    this.editorTarget.classList.add("hidden")
  }
}
