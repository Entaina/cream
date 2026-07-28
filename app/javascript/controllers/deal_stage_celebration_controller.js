import { Controller } from "@hotwired/stimulus"

const WON_ICONS = ["🎉", "🏆", "🎊", "⭐", "✨"]
const LOST_ICONS = ["😞", "💔", "📉", "✗"]
const DURATION_MS = 2500

export default class extends Controller {
  static values = { initialStageId: Number }

  connect() {
    this.kind = null
    this.pendingUrl = null
  }

  onSubmitEnd(event) {
    if (!event.detail.success) return

    const select = this.stageSelect()
    if (select) {
      this.handleEditFormSubmit(select)
      return
    }

    this.handleShowMoveSubmit(event.target)
  }

  handleEditFormSubmit(select) {
    const option = select.selectedOptions[0]
    if (!option) return

    const stageId = parseInt(option.value, 10)
    if (this.hasInitialStageIdValue && stageId === this.initialStageIdValue) return

    this.kind = this.kindForStage(option.dataset.stageWon, option.dataset.stageClosed)
  }

  handleShowMoveSubmit(form) {
    const kind = this.kindForStage(form.dataset.stageWon, form.dataset.stageClosed)
    if (kind) this.play(kind, () => {})
  }

  kindForStage(won, closed) {
    if (won === "true") return "won"
    if (closed === "true") return "lost"
    return null
  }

  onBeforeVisit(event) {
    if (!this.kind) return

    event.preventDefault()
    this.pendingUrl = event.detail.url
    this.play(this.kind, () => {
      const url = this.pendingUrl
      this.kind = null
      this.pendingUrl = null
      window.Turbo.visit(url)
    })
  }

  stageSelect() {
    return this.element.querySelector('select[name="deal[pipeline_stage_id]"]')
  }

  play(kind, done) {
    const overlay = document.createElement("div")
    overlay.className = "stage-celebration-overlay fixed inset-0 z-[100] pointer-events-none overflow-hidden"
    overlay.setAttribute("aria-hidden", "true")

    if (kind === "won") {
      this.spawnIcons(overlay, WON_ICONS, 24, "celebrate-icon")
      this.spawnCenterIcon(overlay, "🏆", "celebrate-center")
    } else {
      this.spawnIcons(overlay, LOST_ICONS, 14, "defeat-icon")
      this.spawnCenterIcon(overlay, "😞", "defeat-center")
    }

    document.body.appendChild(overlay)
    setTimeout(() => {
      overlay.remove()
      done()
    }, DURATION_MS)
  }

  spawnIcons(overlay, icons, count, cssClass) {
    for (let i = 0; i < count; i++) {
      const icon = document.createElement("span")
      icon.textContent = icons[Math.floor(Math.random() * icons.length)]
      icon.className = cssClass
      icon.style.left = `${Math.random() * 100}%`
      icon.style.animationDelay = `${Math.random() * 0.8}s`
      icon.style.animationDuration = `${2 + Math.random() * 1.2}s`
      overlay.appendChild(icon)
    }
  }

  spawnCenterIcon(overlay, emoji, cssClass) {
    const center = document.createElement("span")
    center.textContent = emoji
    center.className = cssClass
    overlay.appendChild(center)
  }
}
