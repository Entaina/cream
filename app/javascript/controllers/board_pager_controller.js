import { Controller } from "@hotwired/stimulus"

// Mobile deals board: scroll-snap paging with prev/next controls and stage indicator.
export default class extends Controller {
  static targets = ["track", "stageColumn", "prevBtn", "nextBtn", "indicator", "stageName"]

  connect() {
    this.onScroll = this.onScroll.bind(this)
    if (this.hasTrackTarget) {
      this.trackTarget.addEventListener("scroll", this.onScroll, { passive: true })
    }
    this.updatePager()
  }

  disconnect() {
    if (this.hasTrackTarget) {
      this.trackTarget.removeEventListener("scroll", this.onScroll)
    }
  }

  prev() {
    this.scrollToIndex(this.currentIndex() - 1)
  }

  next() {
    this.scrollToIndex(this.currentIndex() + 1)
  }

  onScroll() {
    this.updatePager()
  }

  currentIndex() {
    if (!this.hasTrackTarget || !this.stageColumnTargets.length) return 0

    const trackRect = this.trackTarget.getBoundingClientRect()
    const trackCenter = trackRect.left + trackRect.width / 2

    let closestIndex = 0
    let closestDistance = Infinity

    this.stageColumnTargets.forEach((column, index) => {
      const rect = column.getBoundingClientRect()
      const columnCenter = rect.left + rect.width / 2
      const distance = Math.abs(columnCenter - trackCenter)
      if (distance < closestDistance) {
        closestDistance = distance
        closestIndex = index
      }
    })

    return closestIndex
  }

  scrollToIndex(index) {
    const columns = this.stageColumnTargets
    if (!columns.length) return

    const clamped = Math.max(0, Math.min(index, columns.length - 1))
    columns[clamped].scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" })
  }

  updatePager() {
    const index = this.currentIndex()
    const total = this.stageColumnTargets.length

    if (this.hasIndicatorTarget) {
      this.indicatorTarget.textContent = total > 0 ? `${index + 1} / ${total}` : ""
    }

    if (this.hasStageNameTarget) {
      const column = this.stageColumnTargets[index]
      const name = column?.querySelector("[data-board-pager-stage-name]")?.textContent?.trim()
      this.stageNameTarget.textContent = name || ""
    }

    if (this.hasPrevBtnTarget) {
      this.prevBtnTarget.disabled = index <= 0
    }

    if (this.hasNextBtnTarget) {
      this.nextBtnTarget.disabled = index >= total - 1
    }
  }
}
