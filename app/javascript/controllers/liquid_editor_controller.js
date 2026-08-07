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
    this.previewFormId = this.element.dataset.liquidEditorPreviewFormId
    this.previewForm = this.previewFormId ? document.getElementById(this.previewFormId) : null

    this.submitHandler = () => this.sync()
    if (this.form) {
      this.form.addEventListener("submit", this.submitHandler)
    }
    if (this.previewForm) {
      this.previewSubmitHandler = () => this.syncPreviewBody()
      this.previewForm.addEventListener("submit", this.previewSubmitHandler)
    }
  }

  disconnect() {
    if (this.form && this.submitHandler) {
      this.form.removeEventListener("submit", this.submitHandler)
    }
    if (this.previewForm && this.previewSubmitHandler) {
      this.previewForm.removeEventListener("submit", this.previewSubmitHandler)
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

  syncPreviewBody() {
    this.sync()
    const previewBody = this.previewForm?.querySelector('[name="lead_form_template[body]"]')
    if (previewBody) {
      previewBody.value = this.inputTarget.value
    }
  }

  showPlainTextarea() {
    this.inputTarget.classList.remove("sr-only")
    this.inputTarget.classList.add("input", "w-full", "resize-y", "font-mono", "text-sm", "border-0", "rounded-none")
    this.editorTarget.classList.add("hidden")
  }
}
