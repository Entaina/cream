import { Controller } from "@hotwired/stimulus"

// Splits pasted "Name <email>" into first name, last name and plain email (matches EmailAddressParser).
export default class extends Controller {
  static targets = ["firstName", "lastName"]

  paste(event) {
    const text = (event.clipboardData || window.clipboardData)?.getData("text")
    if (!text || !this.looksLikeMailbox(text)) return

    event.preventDefault()
    this.applyParsed(text.trim(), event.currentTarget)
  }

  blurEmail(event) {
    const value = event.currentTarget.value.trim()
    if (!value || !this.looksLikeMailbox(value)) return
    this.applyParsed(value, event.currentTarget)
  }

  looksLikeMailbox(value) {
    return /<[^>]+>/.test(value)
  }

  applyParsed(raw, emailInput) {
    const parsed = this.parse(raw)
    if (!parsed?.email) return

    emailInput.value = parsed.email
    if (!this.hasFirstNameTarget || !this.hasLastNameTarget) return
    if (this.firstNameTarget.value.trim() || this.lastNameTarget.value.trim()) return

    if (parsed.firstName) this.firstNameTarget.value = parsed.firstName
    if (parsed.lastName) this.lastNameTarget.value = parsed.lastName
  }

  parse(raw) {
    const segment = raw.replace(/[,;]+\s*$/, "").trim()
    if (!segment) return null

    let email = null
    let displayName = null
    const angleMatch = segment.match(/^(.+?)<([^>]+)>$/s)

    if (angleMatch) {
      displayName = this.unquoteName(angleMatch[1])
      email = angleMatch[2].trim().toLowerCase()
    } else {
      email = segment.toLowerCase()
    }

    if (!this.validEmail(email)) return null

    const nameParts = displayName ? displayName.trim().split(/\s+/, 2) : []
    return {
      email,
      firstName: nameParts[0] || "",
      lastName: nameParts[1] || ""
    }
  }

  validEmail(value) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
  }

  unquoteName(value) {
    let name = value.trim()
    if (name.startsWith('"') && name.endsWith('"')) {
      name = name.slice(1, -1).trim()
    }
    return name
  }
}
