import { Controller } from "@hotwired/stimulus"

const DEFAULT_SUPPORTED_TAGS = [ "p", "br", "strong", "b", "em", "i", "u", "s", "a", "ul", "ol", "li", "span" ]

export default class extends Controller {
  static targets = [
    "bodyInput",
    "bodyEditorInput",
    "quillPanel",
    "htmlPanel",
    "quillInput",
    "htmlInput",
    "quillModeRadio",
    "htmlModeRadio"
  ]

  static values = {
    mode: String,
    supportedTags: { type: Array, default: DEFAULT_SUPPORTED_TAGS }
  }

  connect() {
    this.showPanel(this.modeValue)
    this.form = this.element.closest("form")
    if (this.form) {
      this.submitHandler = () => this.syncToBodyInput()
      this.form.addEventListener("submit", this.submitHandler)
    }
    this.syncRequestHandler = () => this.syncToBodyInput()
    this.element.addEventListener("email-template-body-editor:sync", this.syncRequestHandler)
    this.setHtmlHandler = (event) => {
      this.pushToHtml(event.detail?.body || "")
      this.setMode("html")
    }
    this.setQuillHandler = (event) => {
      this.pushToQuill(event.detail?.body || "")
      this.setMode("quill")
    }
    this.element.addEventListener("email-template-body-editor:set-html", this.setHtmlHandler)
    this.element.addEventListener("email-template-body-editor:set-quill", this.setQuillHandler)
  }

  disconnect() {
    if (this.form && this.submitHandler) {
      this.form.removeEventListener("submit", this.submitHandler)
    }
    if (this.syncRequestHandler) {
      this.element.removeEventListener("email-template-body-editor:sync", this.syncRequestHandler)
    }
    if (this.setHtmlHandler) {
      this.element.removeEventListener("email-template-body-editor:set-html", this.setHtmlHandler)
    }
    if (this.setQuillHandler) {
      this.element.removeEventListener("email-template-body-editor:set-quill", this.setQuillHandler)
    }
  }

  selectQuill(event) {
    if (this.modeValue === "quill") return

    this.syncFromHtml()
    const html = this.bodyInputTarget.value
    const unsupported = this.unsupportedTags(html)
    if (unsupported.length > 0) {
      const message =
        `El HTML contiene etiquetas que el editor enriquecido no conserva (${unsupported.join(", ")}). ` +
        "Si continúas, se perderán. ¿Cambiar al editor enriquecido?"
      if (!window.confirm(message)) {
        event.preventDefault()
        this.htmlModeRadioTarget.checked = true
        this.quillModeRadioTarget.checked = false
        return
      }
    }

    this.pushToQuill(html)
    this.setMode("quill")
  }

  selectHtml() {
    if (this.modeValue === "html") return

    this.syncFromQuill()
    this.pushToHtml(this.bodyInputTarget.value)
    this.setMode("html")
  }

  syncToBodyInput() {
    if (this.modeValue === "quill") {
      this.syncFromQuill()
    } else {
      this.syncFromHtml()
    }
  }

  syncFromQuill() {
    if (!this.hasQuillInputTarget) return

    this.bodyInputTarget.value = this.quillInputTarget.value
  }

  syncFromHtml() {
    if (!this.hasHtmlInputTarget) return

    const liquidEditor = this.htmlPanelTarget.querySelector('[data-controller~="liquid-editor"]')
    if (liquidEditor) {
      liquidEditor.dispatchEvent(new CustomEvent("liquid-editor:sync", { bubbles: true }))
    }

    this.bodyInputTarget.value = this.htmlInputTarget.value
  }

  pushToQuill(html) {
    this.bodyInputTarget.value = html
    const quillWrapper = this.quillPanelTarget.querySelector('[data-controller~="rich-text-editor"]')
    if (quillWrapper) {
      quillWrapper.dispatchEvent(new CustomEvent("rich-text-editor:set", { detail: { html } }))
    } else if (this.hasQuillInputTarget) {
      this.quillInputTarget.value = html
    }
  }

  pushToHtml(html) {
    this.bodyInputTarget.value = html
    if (this.hasHtmlInputTarget) {
      this.htmlInputTarget.value = html
      const liquidEditor = this.htmlPanelTarget.querySelector('[data-controller~="liquid-editor"]')
      if (liquidEditor) {
        liquidEditor.dispatchEvent(new CustomEvent("liquid-editor:set", { detail: { value: html } }))
      }
    }
  }

  setMode(mode) {
    this.modeValue = mode
    if (this.hasBodyEditorInputTarget) {
      this.bodyEditorInputTarget.value = mode
    }
    this.showPanel(mode)
  }

  showPanel(mode) {
    const quillActive = mode === "quill"
    this.quillPanelTarget.classList.toggle("hidden", !quillActive)
    this.htmlPanelTarget.classList.toggle("hidden", quillActive)
    if (this.hasQuillModeRadioTarget) this.quillModeRadioTarget.checked = quillActive
    if (this.hasHtmlModeRadioTarget) this.htmlModeRadioTarget.checked = !quillActive
  }

  unsupportedTags(html) {
    if (!html) return []

    const tags = [ ...html.matchAll(/<\/?([a-z][a-z0-9]*)\b/gi) ].map((match) => match[1].toLowerCase())
    const unique = [ ...new Set(tags) ]
    return unique.filter((tag) => !this.supportedTagsValue.includes(tag))
  }
}
