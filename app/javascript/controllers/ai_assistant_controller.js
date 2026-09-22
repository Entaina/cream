import { Controller } from "@hotwired/stimulus"

// On-demand AI helpers for CRM record show pages: summary, next steps and email drafts.
export default class extends Controller {
  static targets = [
    "summaryPanel",
    "summaryText",
    "risksList",
    "nextStepsList",
    "missingList",
    "suggestionsPanel",
    "suggestionsList",
    "riskBadge",
    "status",
    "goal"
  ]

  static values = {
    recordType: String,
    recordId: Number,
    summaryUrl: String,
    nextStepsUrl: String,
    draftEmailUrl: String,
    createTaskUrl: String,
    enrichUrl: String,
    enrichmentEnabled: Boolean,
    copy: Object
  }

  get c() {
    return this.copyValue || {}
  }

  label(key) {
    return this.c.labels?.[key] || key
  }

  interpolate(template, vars = {}) {
    if (!template) return ""
    return Object.entries(vars).reduce(
      (text, [key, value]) => text.replace(new RegExp(`%\\{${key}\\}`, "g"), value ?? ""),
      template
    )
  }

  async summarize() {
    await this.run(this.label("summary"), this.summaryUrlValue, (data) => {
      this.summaryPanelTarget.hidden = false
      this.summaryTextTarget.textContent = data.summary || this.c.no_summary
      this.renderList(this.risksListTarget, data.risks, this.c.no_risks)
      this.renderList(this.nextStepsListTarget, data.next_steps, this.c.no_next_steps)
      this.renderList(this.missingListTarget, data.missing_data, this.c.no_missing_data)
    })
  }

  async suggestNextSteps() {
    await this.run(this.label("next_steps"), this.nextStepsUrlValue, (data) => {
      this.suggestionsPanelTarget.hidden = false
      if (this.hasRiskBadgeTarget) {
        this.riskBadgeTarget.textContent = this.interpolate(this.c.risk_badge, {
          level: data.deal_risk || "medium"
        })
        this.riskBadgeTarget.hidden = false
      }
      this.renderSuggestions(data.suggestions || [])
      if (data.summary) {
        this.statusTarget.textContent = data.summary
      }
    })
  }

  async draftEmail() {
    const goal = this.hasGoalTarget ? this.goalTarget.value.trim() : ""
    await this.run(this.label("email_draft"), this.draftEmailUrlValue, (data) => {
      this.fillEmailComposer(data.subject, data.body)
      this.statusTarget.textContent = this.c.email_draft_ready
    }, { goal })
  }

  async enrich() {
    if (!this.enrichmentEnabledValue) return

    await this.run(this.label("enrichment"), this.enrichUrlValue, (data) => {
      this.summaryPanelTarget.hidden = false
      this.summaryTextTarget.textContent = data.summary || this.c.no_enrichment
      const suggestions = (data.suggestions || []).map((item) =>
        `${item.field}: ${item.current || "—"} → ${item.suggested}${item.reason ? ` (${item.reason})` : ""}`
      )
      this.renderList(this.missingListTarget, suggestions, this.c.no_enrichment)
    })
  }

  async createTask(event) {
    const button = event.currentTarget
    const title = button.dataset.title
    const dueOn = button.dataset.dueOn
    const reason = button.dataset.reason

    button.disabled = true
    this.setStatus(this.c.creating_task)

    try {
      const response = await this.postJson(this.createTaskUrlValue, { title, due_on: dueOn, reason })
      const data = await response.json()
      if (!response.ok) {
        throw new Error(data.error || data.errors?.join(", ") || this.c.create_task_failed)
      }

      button.replaceWith(this.createdTaskLabel(data.task.title))
      this.setStatus(this.interpolate(this.c.task_created, { title: data.task.title }))
    } catch (error) {
      button.disabled = false
      this.setStatus(error.message, true)
    }
  }

  async run(label, url, onSuccess, body = {}) {
    this.setStatus(this.interpolate(this.c.generating, { label }))

    try {
      const response = await this.postJson(url, body)
      const data = await response.json()
      if (!response.ok) {
        throw new Error(data.error || this.interpolate(this.c.generate_failed, { label }))
      }

      onSuccess(data)
      this.setStatus("")
    } catch (error) {
      this.setStatus(error.message, true)
    }
  }

  async postJson(url, body) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify(body)
    })
  }

  renderList(target, items, emptyLabel) {
    target.replaceChildren()
    const values = (items || []).filter(Boolean)
    if (values.length === 0) {
      const li = document.createElement("li")
      li.className = "text-ink-faint"
      li.textContent = emptyLabel
      target.appendChild(li)
      return
    }

    values.forEach((value) => {
      const li = document.createElement("li")
      li.textContent = value
      target.appendChild(li)
    })
  }

  renderSuggestions(suggestions) {
    this.suggestionsListTarget.replaceChildren()

    if (suggestions.length === 0) {
      const empty = document.createElement("p")
      empty.className = "text-sm text-ink-faint"
      empty.textContent = this.c.no_suggestions
      this.suggestionsListTarget.appendChild(empty)
      return
    }

    suggestions.forEach((suggestion) => {
      const card = document.createElement("div")
      card.className = "card p-3 space-y-2"

      const title = document.createElement("p")
      title.className = "text-base font-medium text-ink"
      title.textContent = suggestion.title || suggestion.kind.replaceAll("_", " ")
      card.appendChild(title)

      if (suggestion.reason) {
        const reason = document.createElement("p")
        reason.className = "text-sm text-ink-soft"
        reason.textContent = suggestion.reason
        card.appendChild(reason)
      }

      if (suggestion.kind === "task" && suggestion.title) {
        const button = document.createElement("button")
        button.type = "button"
        button.className = "btn-secondary text-sm"
        button.textContent = this.c.create_task
        button.dataset.title = suggestion.title
        button.dataset.dueOn = suggestion.due_on || ""
        button.dataset.reason = suggestion.reason || ""
        button.dataset.action = "ai-assistant#createTask"
        card.appendChild(button)
      }

      this.suggestionsListTarget.appendChild(card)
    })
  }

  fillEmailComposer(subject, body) {
    const subjectField = document.querySelector('[data-template-picker-target="subject"]')
    const bodyField = document.querySelector('[data-template-picker-target="body"]')
    const dialog = subjectField?.closest("dialog")
    if (dialog && !dialog.open) {
      document.querySelector('[data-action="record-workspace#openComposer"][data-composer="email"]')?.click()
    }

    if (subjectField && subject) this.writeFieldValue(subjectField, subject)
    if (bodyField && body) {
      const editor = bodyField.closest('[data-controller~="rich-text-editor"]')
      if (editor) {
        editor.dispatchEvent(new CustomEvent("rich-text-editor:set", { detail: { html: body } }))
        bodyField.dispatchEvent(new Event("input", { bubbles: true }))
      } else {
        this.writeFieldValue(bodyField, body)
      }
    }
  }

  writeFieldValue(field, value) {
    field.focus()
    field.setSelectionRange(0, field.value.length)
    document.execCommand("insertText", false, value)
  }

  createdTaskLabel(title) {
    const span = document.createElement("span")
    span.className = "text-sm text-green-700 dark:text-green-300"
    span.textContent = this.interpolate(this.c.task_created, { title })
    return span
  }

  setStatus(message, isError = false) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-danger", isError)
    this.statusTarget.classList.toggle("text-ink-faint", !isError)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
