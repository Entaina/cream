import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "menu"]
  static values = { usersJson: String }

  connect() {
    this.activeIndex = -1
    this.mentionStart = null
    this.mentionQuery = ""
    this.onMenuMouseDown = this.onMenuMouseDown.bind(this)
    this.menuTarget.addEventListener("mousedown", this.onMenuMouseDown)
  }

  disconnect() {
    this.menuTarget.removeEventListener("mousedown", this.onMenuMouseDown)
  }

  workspaceUsers() {
    try {
      const parsed = JSON.parse(this.usersJsonValue || "[]")
      return Array.isArray(parsed) ? parsed : []
    } catch {
      return []
    }
  }

  query() {
    const input = this.inputTarget
    const cursor = input.selectionStart
    const before = input.value.slice(0, cursor)
    const match = before.match(/@([\w.-]*)$/)

    if (!match) {
      this.hideMenu()
      return
    }

    this.mentionStart = cursor - match[0].length
    this.mentionQuery = match[1].toLowerCase()
    this.renderMenu()
  }

  renderMenu() {
    const q = this.mentionQuery
    const matches = this.workspaceUsers().filter((user) =>
      user.name.toLowerCase().includes(q) || user.handle.toLowerCase().startsWith(q)
    ).slice(0, 8)

    if (matches.length === 0) {
      this.hideMenu()
      return
    }

    this.menuTarget.innerHTML = matches.map((user, index) => {
      const name = this.escapeHtml(user.name)
      const handle = this.escapeHtml(user.handle)
      return `<li role="option" data-index="${index}" data-handle="${handle}" class="cursor-pointer px-3 py-1.5 text-base hover:bg-canvas-sunken"><span class="font-medium">${name}</span> <span class="text-ink-faint">@${handle}</span></li>`
    }).join("")

    this.activeIndex = 0
    this.highlightActive()
    this.element.classList.add("z-50")
    this.menuTarget.classList.remove("hidden")
  }

  keydown(event) {
    if (this.menuTarget.classList.contains("hidden")) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, this.menuTarget.children.length - 1)
      this.highlightActive()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlightActive()
    } else if (event.key === "Enter" || event.key === "Tab") {
      event.preventDefault()
      const item = this.menuTarget.children[this.activeIndex]
      if (item) this.insertMention(item.dataset.handle)
    } else if (event.key === "Escape") {
      this.hideMenu()
    }
  }

  onMenuMouseDown(event) {
    const item = event.target.closest("[data-handle]")
    if (!item) return

    event.preventDefault()
    this.insertMention(item.dataset.handle)
  }

  insertMention(handle) {
    const input = this.inputTarget
    const cursor = input.selectionStart
    const before = input.value.slice(0, this.mentionStart)
    const after = input.value.slice(cursor)
    const mention = `@${handle} `
    input.value = before + mention + after
    const newCursor = before.length + mention.length
    input.setSelectionRange(newCursor, newCursor)
    this.hideMenu()
    input.focus()
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  hide() {
    setTimeout(() => this.hideMenu(), 150)
  }

  hideMenu() {
    this.menuTarget.classList.add("hidden")
    this.menuTarget.innerHTML = ""
    this.element.classList.remove("z-50")
    this.activeIndex = -1
  }

  highlightActive() {
    Array.from(this.menuTarget.children).forEach((element, index) => {
      element.classList.toggle("bg-canvas-sunken", index === this.activeIndex)
    })
  }

  escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/"/g, "&quot;")
  }
}
