import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "templateSelect", "layoutSelect", "subjectInput" ]

  static values = {
    templateUrl: String
  }

  templateSelected(event) {
    const templateId = event.target.value
    if (!templateId) return

    const hasContent = this.subjectInputTarget.value.trim().length > 0 ||
      this.readBodyValue().trim().length > 0

    if (hasContent) {
      const proceed = window.confirm(
        "¿Sustituir el asunto y cuerpo actuales por los de la plantilla seleccionada?"
      )
      if (!proceed) {
        event.target.value = event.target.dataset.previousValue || ""
        return
      }
    }

    event.target.dataset.previousValue = templateId

    fetch(`${this.templateUrlValue}/${templateId}.json`, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Template fetch failed (${response.status})`)
        return response.json()
      })
      .then((data) => this.applyTemplate(data))
      .catch((error) => {
        console.error("Failed to load email template", error)
        window.alert("No se pudo cargar la plantilla.")
      })
  }

  applyTemplate(data) {
    if (this.hasSubjectInputTarget) {
      this.subjectInputTarget.value = data.subject || ""
    }

    if (this.hasLayoutSelectTarget && data.email_layout_id) {
      this.layoutSelectTarget.value = data.email_layout_id
    }

    const bodyEditor = this.element.querySelector('[data-controller~="email-template-body-editor"]')
    if (!bodyEditor) return

    const mode = data.body_editor || "quill"
    const bodyInput = bodyEditor.querySelector('[data-email-template-body-editor-target="bodyInput"]')
    const bodyEditorInput = bodyEditor.querySelector('[data-email-template-body-editor-target="bodyEditorInput"]')
    if (bodyInput) bodyInput.value = data.body || ""
    if (bodyEditorInput) bodyEditorInput.value = mode

    if (mode === "html") {
      bodyEditor.dispatchEvent(new CustomEvent("email-template-body-editor:set-html", {
        detail: { body: data.body || "" },
        bubbles: true
      }))
    } else {
      bodyEditor.dispatchEvent(new CustomEvent("email-template-body-editor:set-quill", {
        detail: { body: data.body || "" },
        bubbles: true
      }))
    }
  }

  readBodyValue() {
    const bodyEditor = this.element.querySelector('[data-controller~="email-template-body-editor"]')
    if (!bodyEditor) return ""

    bodyEditor.dispatchEvent(new CustomEvent("email-template-body-editor:sync", { bubbles: true }))
    const bodyInput = bodyEditor.querySelector('[data-email-template-body-editor-target="bodyInput"]')
    return bodyInput?.value || ""
  }
}
