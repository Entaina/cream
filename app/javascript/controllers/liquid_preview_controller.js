import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "editor" ]

  async connect() {
    const doc = this.sourceTarget.value

    try {
      const { createLiquidEditor } = await import("codemirror-liquid-editor")
      this.view = createLiquidEditor(this.editorTarget, { doc, readOnly: true })
      this.constrainHeight()
    } catch (error) {
      console.error("Liquid preview failed to initialize", error)
      this.showFallback(doc)
    }
  }

  disconnect() {
    if (this.view) {
      this.view.destroy()
      this.view = null
    }
  }

  constrainHeight() {
    this.element.style.height = "10rem"
    this.element.style.maxHeight = "10rem"
    this.editorTarget.style.height = "100%"
    this.editorTarget.style.maxHeight = "100%"
    this.editorTarget.style.overflow = "hidden"

    const editor = this.editorTarget.querySelector(".cm-editor")
    const scroller = this.editorTarget.querySelector(".cm-scroller")
    if (editor) {
      editor.style.height = "100%"
      editor.style.maxHeight = "100%"
    }
    if (scroller) {
      scroller.style.height = "100%"
      scroller.style.maxHeight = "100%"
      scroller.style.overflow = "auto"
    }
  }

  showFallback(doc) {
    this.editorTarget.classList.add(
      "h-40", "overflow-y-auto", "rounded-md", "border", "border-line",
      "bg-canvas-sunken", "p-3", "text-xs", "font-mono", "whitespace-pre-wrap"
    )
    this.editorTarget.textContent = doc
  }
}
