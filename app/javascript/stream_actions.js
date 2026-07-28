// Custom Turbo Stream actions used by stage triggers to drive the UI from the
// server. All user-provided text goes through textContent — never innerHTML —
// so LLM output cannot inject markup or scripts.
import "@hotwired/turbo-rails"

function buildDialog({ title, message }) {
  const dialog = document.createElement("dialog")
  dialog.className = "rounded-xl shadow-xl ring-1 ring-line p-0 w-full max-w-sm backdrop:bg-ink/20 m-auto"

  const body = document.createElement("div")
  body.className = "p-5 space-y-3 bg-canvas-raised rounded-xl"

  if (title) {
    const heading = document.createElement("h3")
    heading.className = "text-base font-semibold text-ink"
    heading.textContent = title
    body.appendChild(heading)
  }

  const text = document.createElement("p")
  text.className = "text-base text-ink-soft whitespace-pre-wrap"
  text.textContent = message
  body.appendChild(text)

  const actions = document.createElement("div")
  actions.className = "flex justify-end gap-2 pt-1"
  body.appendChild(actions)

  dialog.appendChild(body)
  dialog.addEventListener("close", () => dialog.remove())
  document.body.appendChild(dialog)
  return { dialog, actions }
}

function button(label, className) {
  const el = document.createElement("button")
  el.type = "button"
  el.className = className
  el.textContent = label
  return el
}

function localToast(message) {
  const container = document.getElementById("toasts")
  if (!container) return
  const toast = document.createElement("div")
  toast.className = "pointer-events-auto flex items-center gap-2 rounded-lg px-4 py-2 text-base shadow-lg ring-1 bg-canvas-raised text-ink ring-line-strong"
  toast.textContent = message
  toast.setAttribute("data-controller", "flash")
  toast.setAttribute("data-flash-target", "message")
  container.appendChild(toast)
}

Turbo.StreamActions.stage_trigger_alert = function () {
  const { dialog, actions } = buildDialog({
    title: this.getAttribute("title"),
    message: this.getAttribute("message") || ""
  })
  const ok = button("Aceptar", "btn-primary")
  ok.addEventListener("click", () => dialog.close())
  actions.appendChild(ok)
  dialog.showModal()
}

Turbo.StreamActions.stage_trigger_confirm = function () {
  const followUpType = this.getAttribute("follow-up-type")
  const followUpUrl = this.getAttribute("follow-up-url")
  const followUpMessage = this.getAttribute("follow-up-message")

  const { dialog, actions } = buildDialog({
    title: this.getAttribute("title"),
    message: this.getAttribute("message") || ""
  })
  const cancel = button("Cancelar", "btn-secondary")
  cancel.addEventListener("click", () => dialog.close())
  const confirm = button("Aceptar", "btn-primary")
  confirm.addEventListener("click", () => {
    dialog.close()
    if (followUpType === "visit" && followUpUrl && followUpUrl.startsWith("/")) {
      Turbo.visit(followUpUrl)
    } else if (followUpType === "toast" && followUpMessage) {
      localToast(followUpMessage)
    }
  })
  actions.appendChild(cancel)
  actions.appendChild(confirm)
  dialog.showModal()
}
