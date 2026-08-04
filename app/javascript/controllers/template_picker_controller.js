import { Controller } from "@hotwired/stimulus"

// Fills the Send email subject/body from a selected template, interpolating
// {first_name}, {last_name}, {name}, {company}, {email} with the record's
// values (mirrors EmailTemplate#template_value on the server).
export default class extends Controller {
  static targets = ["select", "subject", "body", "templateId", "attachmentList"]
  static values = {
    firstName: String,
    lastName: String,
    name: String,
    company: String,
    email: String
  }

  apply() {
    const option = this.selectTarget.selectedOptions[0]
    if (!option || !option.value) return

    const subject = this.interpolate(option.dataset.subject || "")
    const body = this.interpolate(option.dataset.body || "")

    if (subject && this.hasSubjectTarget) this.writeFieldValue(this.subjectTarget, subject)
    if (this.hasBodyTarget) this.writeBodyValue(body)

    if (this.hasTemplateIdTarget) this.templateIdTarget.value = option.value
    this.showTemplateAttachments(option.dataset.attachments)

    // Reset so the picker reads "Insertar plantilla…" again.
    this.selectTarget.value = ""
  }

  showTemplateAttachments(raw) {
    if (!this.hasAttachmentListTarget) return

    this.attachmentListTarget.querySelectorAll("[data-template-attachment]").forEach((item) => item.remove())

    let attachments = []
    if (raw) {
      try {
        attachments = JSON.parse(raw)
      } catch (_error) {
        attachments = []
      }
    }

    attachments.forEach((attachment) => {
      const item = document.createElement("li")
      item.className = "flex items-center gap-2 text-sm"
      item.dataset.templateAttachment = "true"

      const label = document.createElement("label")
      label.className = "flex items-center gap-2 cursor-pointer"

      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.name = "email_template_attachment_ids[]"
      checkbox.value = attachment.id
      checkbox.checked = true
      checkbox.className = "rounded border-line"

      const name = document.createElement("span")
      name.className = "text-ink-soft"
      name.textContent = attachment.filename

      const size = document.createElement("span")
      size.className = "text-xs text-ink-faint"
      size.textContent = this.formatSize(attachment.byte_size)

      label.append(checkbox, name, size)
      item.appendChild(label)
      this.attachmentListTarget.appendChild(item)
    })
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  // Assign via insertText so Ctrl+Z can undo template insertion (direct .value= clears undo stack).
  writeFieldValue(field, value) {
    field.focus()
    field.setSelectionRange(0, field.value.length)
    document.execCommand("insertText", false, value)
  }

  writeBodyValue(value) {
    const editorWrapper = this.bodyTarget.closest('[data-controller~="rich-text-editor"]')
    if (editorWrapper) {
      editorWrapper.dispatchEvent(new CustomEvent("rich-text-editor:set", {
        detail: { html: value }
      }))
      return
    }

    this.writeFieldValue(this.bodyTarget, value)
  }

  interpolate(text) {
    const values = {
      first_name: this.firstNameValue,
      last_name: this.lastNameValue,
      name: this.nameValue,
      company: this.companyValue,
      email: this.emailValue
    }
    return text.replace(/\{(\w+)\}/g, (match, token) =>
      Object.prototype.hasOwnProperty.call(values, token) ? values[token] : match
    )
  }
}
