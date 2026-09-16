import { Controller } from "@hotwired/stimulus"

// Toggles email vs journey fields on the campaign send form.
export default class extends Controller {
  static targets = [
    "deliveryMode",
    "journeyField",
    "journeySelect",
    "emailFields",
    "emailWarning",
    "submit",
    "emailContentRequired"
  ]

  static values = {
    emailContentPresent: Boolean
  }

  connect() {
    this.refresh()
  }

  modeChanged() {
    this.refresh()
  }

  refresh() {
    const mode = this.deliveryModeTarget.value
    const sendsEmail = mode === "email" || mode === "both"
    const enrollsJourney = mode === "journey" || mode === "both"

    if (this.hasJourneyFieldTarget) {
      this.journeyFieldTarget.hidden = !enrollsJourney
      if (this.hasJourneySelectTarget) {
        this.journeySelectTarget.required = enrollsJourney
        if (!enrollsJourney) this.journeySelectTarget.value = ""
      }
    }

    if (this.hasEmailFieldsTarget) {
      this.emailFieldsTarget.hidden = !sendsEmail
    }

    if (this.hasEmailWarningTarget) {
      this.emailWarningTarget.hidden = !(sendsEmail && !this.emailContentPresentValue)
    }

    if (this.hasSubmitTarget) {
      const emailBlocked = sendsEmail && !this.emailContentPresentValue
      const journeyBlocked = enrollsJourney && this.hasJourneySelectTarget && !this.journeySelectTarget.value
      this.submitTarget.disabled = emailBlocked || journeyBlocked
    }
  }

  journeyChanged() {
    this.refresh()
  }
}
