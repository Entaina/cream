import { Controller } from "@hotwired/stimulus"

// Keeps clicks inside this element from reaching a clickable parent (row links, summaries).
export default class extends Controller {
  stop(event) {
    event.stopPropagation()
  }
}
