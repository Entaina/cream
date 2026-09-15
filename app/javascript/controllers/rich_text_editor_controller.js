import { Controller } from "@hotwired/stimulus"
import Quill from "quill"

const STYLE_ATTRIBUTORS = [
  "attributors/style/align",
  "attributors/style/background",
  "attributors/style/color",
  "attributors/style/size"
]

STYLE_ATTRIBUTORS.forEach((path) => {
  Quill.register(Quill.import(path), true)
})

const SizeStyle = Quill.import("attributors/style/size")
SizeStyle.whitelist = [ "12px", "14px", "16px", "18px", "24px" ]
Quill.register(SizeStyle, true)

Quill.register({
  "formats/align": Quill.import("attributors/style/align"),
  "formats/size": SizeStyle
}, true)

export default class extends Controller {
  static targets = [ "input", "editor" ]

  connect() {
    this.quill = new Quill(this.editorTarget, {
      theme: "snow",
      modules: {
        toolbar: [
          [ "bold", "italic", "underline", "strike" ],
          [ { color: [] }, { background: [] } ],
          [ { size: SizeStyle.whitelist } ],
          [ { list: "ordered" }, { list: "bullet" } ],
          [ { align: [] } ],
          [ "link" ],
          [ "clean" ]
        ]
      },
      placeholder: this.inputTarget.getAttribute("placeholder") || ""
    })

    this.loadInitialContent(this.inputTarget.value)
    this.quill.on("text-change", () => this.sync())
    this.setContentHandler = (event) => this.setContent(event.detail?.html ?? "")
    this.element.addEventListener("rich-text-editor:set", this.setContentHandler)
    this.syncRequestHandler = () => this.sync()
    this.element.addEventListener("rich-text-editor:sync-request", this.syncRequestHandler)

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
    if (this.setContentHandler) {
      this.element.removeEventListener("rich-text-editor:set", this.setContentHandler)
    }
    if (this.syncRequestHandler) {
      this.element.removeEventListener("rich-text-editor:sync-request", this.syncRequestHandler)
    }
    this.quill = null
  }

  loadInitialContent(value) {
    this.setContent(value || "")
  }

  setContent(value) {
    this.quill.setContents([])
    const text = value || ""

    if (text.includes("<")) {
      this.quill.clipboard.dangerouslyPasteHTML(text)
    } else if (text) {
      const html = text
        .split(/\r?\n/)
        .map((line) => `<p>${this.escapeHtml(line) || "<br>"}</p>`)
        .join("")
      this.quill.clipboard.dangerouslyPasteHTML(html)
    }

    this.sync()
  }

  sync() {
    const html = this.quill.root.innerHTML
    this.inputTarget.value = html === "<p><br></p>" ? "" : html
  }

  escapeHtml(text) {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
