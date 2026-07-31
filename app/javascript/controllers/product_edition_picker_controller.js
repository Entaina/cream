import { Controller } from "@hotwired/stimulus"

// Wires a product <select> to an edition record-picker: updates search/create URLs per product
// and preloads that product's editions for inline filtering.
export default class extends Controller {
  static targets = [ "productSelect", "picker" ]
  static values = {
    searchUrlTemplate: String,
    createUrlTemplate: String
  }

  connect() {
    if (this.hasProductSelectTarget) {
      queueMicrotask(() => this.productChanged())
    }
  }

  async productChanged() {
    if (!this.hasPickerTarget) return

    const pickerEl = this.pickerTarget.closest("[data-controller~='record-picker']")
    const picker = this.application.getControllerForElementAndIdentifier(pickerEl, "record-picker")
    if (!picker) return

    const productId = this.hasProductSelectTarget ? this.productSelectTarget.value : ""
    if (!productId) {
      picker.searchUrlValue = ""
      picker.createUrlValue = ""
      picker.setInlineRecords([])
      picker.inputTarget.disabled = true
      picker.clear()
      return
    }

    picker.searchUrlValue = this.searchUrlTemplateValue.replace("__PRODUCT_ID__", productId)
    picker.createUrlValue = this.createUrlTemplateValue.replace("__PRODUCT_ID__", productId)
    picker.inputTarget.disabled = false
    picker.clear()
    await this.loadEditions(picker)
  }

  async loadEditions(picker) {
    if (!picker.searchUrlValue) {
      picker.setInlineRecords([])
      return
    }

    try {
      const response = await fetch(`${picker.searchUrlValue}?q=`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) {
        picker.setInlineRecords([])
        return
      }

      picker.setInlineRecords(await response.json())
    } catch {
      picker.setInlineRecords([])
    }
  }
}
