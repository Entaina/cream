import { Controller } from "@hotwired/stimulus"

// Floating contextual OKM chat: CRM page context + knowledge base + agent tools.
export default class extends Controller {
  static targets = [
    "panel", "toggle", "messages", "input", "status", "submit", "contextLabel",
    "expandButton", "expandIcon", "shrinkIcon", "confirmTemplate"
  ]

  static values = {
    url: String,
    actionsUrl: String,
    recordType: String,
    recordId: String,
    recordLabel: String,
    copy: Object
  }

  get c() {
    try {
      const copy = this.copyValue
      return copy && typeof copy === "object" ? copy : {}
    } catch {
      return {}
    }
  }

  interpolate(template, vars = {}) {
    if (!template) return ""
    return Object.entries(vars).reduce(
      (text, [key, value]) => text.replace(new RegExp(`%\\{${key}\\}`, "g"), value ?? ""),
      template
    )
  }

  connect() {
    this.history = this.loadHistory()
    this.sessionId = this.loadSessionId()
    this.open = false
    this.expanded = false
    this.renderHistory()
    this.updateContextLabel()
  }

  toggle() {
    if (this.open) {
      this.close()
    } else {
      this.openPanel()
    }
  }

  openPanel() {
    this.open = true
    this.panelTarget.hidden = false
    this.applyExpandedLayout()
    this.inputTarget.focus()
  }

  close() {
    this.open = false
    this.expanded = false
    this.panelTarget.hidden = true
    this.applyExpandedLayout()
  }

  toggleExpand() {
    this.expanded = !this.expanded
    this.applyExpandedLayout()
  }

  applyExpandedLayout() {
    this.element.classList.toggle("okm-chat-root--expanded", this.expanded)
    this.panelTarget.classList.toggle("okm-chat-panel--expanded", this.expanded)

    if (this.hasExpandIconTarget && this.hasShrinkIconTarget) {
      this.expandIconTarget.hidden = this.expanded
      this.shrinkIconTarget.hidden = !this.expanded
    }

    if (this.hasExpandButtonTarget) {
      this.expandButtonTarget.setAttribute(
        "aria-label",
        this.expanded ? this.c.shrink : this.c.expand
      )
    }

    if (this.hasToggleTarget) {
      this.toggleTarget.hidden = this.open
    }
  }

  resetConversation() {
    this.history = []
    this.sessionId = null
    this.saveHistory()
    this.saveSessionId()
    this.messagesTarget.replaceChildren()
    this.setStatus("")
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.send(event)
    }
  }

  async send(event) {
    event?.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message || this.busy) return

    this.appendMessage("user", message)
    this.history.push({ role: "user", content: message })
    this.saveHistory()
    this.inputTarget.value = ""
    this.setBusy(true)

    try {
      this.setStatus(this.c.thinking || "")
      const { reply, confirmActions, sessionId } = await this.streamChat({
        message,
        history: this.history.slice(0, -1),
        session_id: this.sessionId,
        record_type: this.recordTypeValue || null,
        record_id: this.recordIdValue || null
      })

      if (sessionId) {
        this.sessionId = sessionId
        this.saveSessionId()
      }

      this.appendMessage("assistant", reply)
      this.history.push({ role: "assistant", content: reply })
      this.saveHistory()

      for (const action of confirmActions) {
        this.appendConfirmAction(action)
      }

      this.setStatus("")
    } catch (error) {
      this.setStatus(error.message, true)
    } finally {
      this.setBusy(false)
    }
  }

  async streamChat(body) {
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/x-ndjson",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify(body)
    })

    if (!response.ok && !response.body) {
      const data = await response.json().catch(() => ({}))
      throw new Error(data.error || this.c.request_failed)
    }

    const reader = response.body?.getReader()
    if (!reader) {
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || this.c.request_failed)
      return { reply: data.reply || this.c.no_reply, confirmActions: [], sessionId: null }
    }

    const decoder = new TextDecoder()
    let buffer = ""
    let reply = null
    let error = null
    let sessionId = null
    const confirmActions = []

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split("\n")
      buffer = lines.pop() || ""

      for (const line of lines) {
        if (!line.trim()) continue

        const event = JSON.parse(line)
        if (event.type === "status" && event.message) {
          this.setStatus(event.message)
        } else if (event.type === "reply") {
          reply = event.content || this.c.no_reply
        } else if (event.type === "session" && event.session_id) {
          sessionId = event.session_id
        } else if (event.type === "confirm_action") {
          confirmActions.push({ description: event.description, token: event.token })
        } else if (event.type === "error") {
          error = event.message || this.c.request_failed
        }
      }
    }

    if (error) throw new Error(error)
    if (!response.ok) throw new Error(error || this.c.request_failed)
    return { reply: reply || this.c.no_reply, confirmActions, sessionId }
  }

  appendConfirmAction(action) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex justify-start"
    wrapper.dataset.okmChatConfirm = "true"

    const card = document.createElement("div")
    card.className = "max-w-[90%] rounded-lg px-3 py-2 text-base bg-canvas-sunken text-ink border border-line space-y-2"

    const text = document.createElement("p")
    text.textContent = action.description
    card.appendChild(text)

    const buttons = document.createElement("div")
    buttons.className = "flex gap-2"

    const confirmBtn = document.createElement("button")
    confirmBtn.type = "button"
    confirmBtn.className = "btn-primary text-xs px-2 py-1"
    confirmBtn.textContent = this.c.confirm || ""
    confirmBtn.addEventListener("click", () => this.executeAction(action, wrapper, confirmBtn))

    const cancelBtn = document.createElement("button")
    cancelBtn.type = "button"
    cancelBtn.className = "btn-ghost text-xs px-2 py-1"
    cancelBtn.textContent = this.c.cancel || ""
    cancelBtn.addEventListener("click", () => wrapper.remove())

    buttons.appendChild(confirmBtn)
    buttons.appendChild(cancelBtn)
    card.appendChild(buttons)
    wrapper.appendChild(card)
    this.messagesTarget.appendChild(wrapper)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  async executeAction(action, wrapper, button) {
    button.disabled = true
    this.setStatus(this.c.executing_action || "")

    try {
      const response = await fetch(this.actionsUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ token: action.token })
      })

      const data = await response.json()
      if (!response.ok || !data.success) {
        throw new Error(data.message || data.error || this.c.action_failed)
      }

      wrapper.remove()
      this.appendMessage("assistant", data.message)
      this.history.push({ role: "assistant", content: data.message })
      this.saveHistory()
      this.setStatus("")
    } catch (error) {
      this.setStatus(error.message, true)
      button.disabled = false
    }
  }

  appendMessage(role, content) {
    const wrapper = document.createElement("div")
    wrapper.className = role === "user"
      ? "flex justify-end"
      : "flex justify-start"

    const bubble = document.createElement("div")
    bubble.className = [
      "max-w-[90%] rounded-lg px-3 py-2 text-base whitespace-pre-wrap break-words",
      role === "user" ? "bg-accent text-on-dark" : "bg-canvas-sunken text-ink border border-line"
    ].join(" ")
    bubble.textContent = content
    wrapper.appendChild(bubble)
    this.messagesTarget.appendChild(wrapper)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  renderHistory() {
    this.messagesTarget.replaceChildren()
    this.history.forEach((turn) => this.appendMessage(turn.role, turn.content))
  }

  updateContextLabel() {
    if (!this.hasContextLabelTarget) return

    const label = this.recordLabelValue?.trim()
    this.contextLabelTarget.textContent = label
      ? this.interpolate(this.c.context, { label })
      : this.c.general_knowledge
  }

  setBusy(busy) {
    this.busy = busy
    this.submitTarget.disabled = busy
    this.inputTarget.disabled = busy
  }

  setStatus(message, isError = false) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-danger", isError)
    this.statusTarget.classList.toggle("text-ink-faint", !isError)
  }

  loadHistory() {
    try {
      const raw = sessionStorage.getItem(this.storageKey)
      return raw ? JSON.parse(raw) : []
    } catch {
      return []
    }
  }

  saveHistory() {
    sessionStorage.setItem(this.storageKey, JSON.stringify(this.history))
  }

  loadSessionId() {
    return sessionStorage.getItem(this.sessionStorageKey) || null
  }

  saveSessionId() {
    if (this.sessionId) {
      sessionStorage.setItem(this.sessionStorageKey, this.sessionId)
    } else {
      sessionStorage.removeItem(this.sessionStorageKey)
    }
  }

  get storageKey() {
    return "cream:okm-chat:history"
  }

  get sessionStorageKey() {
    return "cream:okm-chat:session-id"
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
