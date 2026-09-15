import { Controller } from "@hotwired/stimulus"

const STANDARD_TOKENS = [ "first_name", "last_name", "name", "company", "email" ]

export default class extends Controller {
  static targets = [ "tokenFields", "tokenInput", "sampleContent" ]

  static values = {
    previewUrl: String,
    sourceFormId: String,
    prefilled: Object
  }

  connect() {
    this.sourceForm = document.getElementById(this.sourceFormIdValue)
    if (this.sourceForm) {
      this.inputHandler = () => this.refreshDynamicTokenFields()
      this.sourceForm.addEventListener("input", this.inputHandler)
      this.sourceForm.addEventListener("change", this.inputHandler)
    }
    this.refreshDynamicTokenFields()
  }

  disconnect() {
    if (this.sourceForm && this.inputHandler) {
      this.sourceForm.removeEventListener("input", this.inputHandler)
      this.sourceForm.removeEventListener("change", this.inputHandler)
    }
  }

  open(event) {
    event.preventDefault()
    this.syncEditors()

    fetch(this.previewUrlValue, {
      method: "POST",
      body: this.buildFormData(),
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "text/html"
      },
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Preview failed (${response.status})`)
        return response.text()
      })
      .then((html) => {
        const previewWindow = window.open("", "_blank")
        if (!previewWindow) {
          window.alert("Permite las ventanas emergentes para ver la vista previa.")
          return
        }
        previewWindow.document.open()
        previewWindow.document.write(html)
        previewWindow.document.close()
      })
      .catch((error) => {
        console.error("Email preview failed", error)
        window.alert("No se pudo abrir la vista previa.")
      })
  }

  buildFormData() {
    const formData = new FormData()
    const subject = this.readSubjectValue()
    const body = this.readBodyValue()

    formData.append("subject", subject)
    formData.append("body", body)

    const layoutId = this.readLayoutValue()
    if (layoutId) formData.append("email_layout_id", layoutId)

    const recordType = this.readFieldValue('[name="record_type"]')
    const recordId = this.readFieldValue('[name="record_id"]')
    if (recordType) formData.append("record_type", recordType)
    if (recordId) formData.append("record_id", recordId)

    if (this.hasSampleContentTarget) {
      formData.append("sample_content", this.sampleContentTarget.value)
    }

    this.tokenInputTargets.forEach((input) => {
      formData.append(`preview_tokens[${input.dataset.tokenName}]`, input.value)
    })

    return formData
  }

  syncEditors() {
    const richEditor = this.sourceForm?.querySelector('[data-controller~="rich-text-editor"]')
    if (richEditor) {
      richEditor.dispatchEvent(new CustomEvent("rich-text-editor:sync-request", { bubbles: true }))
    }

    const bodyEditor = this.sourceForm?.querySelector('[data-controller~="email-template-body-editor"]')
    if (bodyEditor) {
      bodyEditor.dispatchEvent(new CustomEvent("email-template-body-editor:sync", { bubbles: true }))
    }

    const liquidEditor = this.sourceForm?.querySelector('[data-controller~="liquid-editor"]')
    if (liquidEditor) {
      liquidEditor.dispatchEvent(new CustomEvent("liquid-editor:sync", { bubbles: true }))
    }
  }

  readSubjectValue() {
    return this.readScopedFieldValue('[data-email-composer-target="subjectInput"], [name*="[subject]"], [name="subject"], [name="email_message[subject]"]')
  }

  readBodyValue() {
    const scope = this.scopeRoot
    const bodyEditor = scope?.querySelector('[data-controller~="email-template-body-editor"]')
    if (bodyEditor) {
      bodyEditor.dispatchEvent(new CustomEvent("email-template-body-editor:sync", { bubbles: true }))
      const bodyInput = bodyEditor.querySelector('[data-email-template-body-editor-target="bodyInput"]')
      if (bodyInput?.value) return bodyInput.value
    }

    const richEditor = scope?.querySelector('[data-controller~="rich-text-editor"]')
    if (richEditor) {
      const quillInput = richEditor.querySelector('[data-rich-text-editor-target="input"]')
      if (quillInput?.value) return quillInput.value
    }

    const liquidEditor = scope?.querySelector('[data-controller~="liquid-editor"]')
    if (liquidEditor) {
      const htmlInput = liquidEditor.querySelector('[data-liquid-editor-target="input"]')
      if (htmlInput?.value) return htmlInput.value
    }

    return this.readScopedFieldValue('[name*="[body]"]:not([name*="body_editor"]), [name="body"], [name="email_message[body]"]')
  }

  readLayoutValue() {
    return this.readScopedFieldValue('[data-email-composer-target="layoutSelect"], [name*="[email_layout_id]"]')
  }

  readScopedFieldValue(selector) {
    const field = this.scopeRoot?.querySelector(selector)
    return field?.value || ""
  }

  readFieldValue(selector) {
    return this.readScopedFieldValue(selector)
  }

  get scopeRoot() {
    const composer = this.element.closest('[data-controller~="email-composer"]')
    return composer || this.sourceForm
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  refreshDynamicTokenFields() {
    if (!this.hasTokenFieldsTarget) return

    const tokens = this.extractTokens()
    const existing = new Set(this.tokenInputTargets.map((input) => input.dataset.tokenName))

    tokens.forEach((token) => {
      if (existing.has(token)) return

      const wrapper = document.createElement("div")
      wrapper.dataset.dynamicPreviewToken = "true"

      const label = document.createElement("label")
      label.className = "label text-xs"
      label.htmlFor = `preview_token_${token}_${this.sourceFormIdValue}`
      label.textContent = `{${token}}`

      const input = document.createElement("input")
      input.type = "text"
      input.id = `preview_token_${token}_${this.sourceFormIdValue}`
      input.className = "input w-full py-1 text-sm"
      input.dataset.emailPreviewTarget = "tokenInput"
      input.dataset.tokenName = token
      input.placeholder = this.prefilledValue[token] || ""

      wrapper.append(label, input)
      this.tokenFieldsTarget.appendChild(wrapper)
    })
  }

  extractTokens() {
    if (!this.sourceForm) return []

    const chunks = [
      this.readSubjectValue(),
      this.readBodyValue(),
      this.hasSampleContentTarget ? this.sampleContentTarget.value : null
    ].filter(Boolean)

    const found = new Set()
    chunks.join("\n").replace(/\{(\w+)\}/g, (_, token) => found.add(token))
    chunks.join("\n").replace(/\{\{\s*(\w+)\s*\}\}/g, (_, token) => {
      if (token !== "content") found.add(token)
    })

    return [ ...found ].filter((token) => !STANDARD_TOKENS.includes(token)).sort()
  }
}
