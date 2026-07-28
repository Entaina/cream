import { Controller } from "@hotwired/stimulus"

// Toggles the LLM instructions / native function fields depending on the
// selected execution mode, and shows the description and parameter fields of
// the chosen function. Hidden parameter fieldsets are disabled so only the
// selected function's params are submitted.
export default class extends Controller {
  static targets = ["mode", "llmFields", "nativeFields", "nativeFunction", "hint", "paramFields"]

  connect() {
    this.refresh()
  }

  refresh() {
    const mode = this.modeTarget.value
    if (this.hasLlmFieldsTarget) this.llmFieldsTarget.hidden = mode !== "llm"
    if (this.hasNativeFieldsTarget) this.nativeFieldsTarget.hidden = mode !== "native"

    const fn = this.hasNativeFunctionTarget ? this.nativeFunctionTarget.value : null
    this.hintTargets.forEach((el) => {
      el.hidden = el.dataset.function !== fn
    })
    this.paramFieldsTargets.forEach((el) => {
      const active = mode === "native" && el.dataset.function === fn
      el.hidden = !active
      el.disabled = !active
    })
  }
}
