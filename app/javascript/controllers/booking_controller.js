import { Controller } from "@hotwired/stimulus"

const LOCATION_ICONS = {
  google_meet: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m16 13 5.223 3.482a.5.5 0 0 0 .777-.416V7.87a.5.5 0 0 0-.752-.432L16 10.5"/><rect x="2" y="6" width="14" height="12" rx="2"/></svg>`,
  physical: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/></svg>`,
  to_be_decided: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384"/></svg>`
}

export default class extends Controller {
  static targets = [
    "profile", "headingChoose", "eventTypeGrid", "stepEventTypes", "stepSchedule", "stepForm", "stepConfirmation",
    "backToTypesWrap", "backToTypesLabel", "backToScheduleLabel", "monthLabel", "calendarGrid", "scheduleError", "timezoneLabel", "timezoneSelect",
    "eventSummary", "slotsHeading", "slotsList", "nextButton", "form", "formFields", "formSummary", "formError",
    "firstNameField", "lastNameField", "emailField", "phoneField", "messageField", "guestsSection",
    "confirmPanel", "confirmHeading", "confirmSummary",
    "firstNameLabel", "lastNameLabel", "emailLabel", "phoneLabel", "messageLabel", "addGuestsLabel", "guestsFields",
    "submitLabel", "confirmedHeading", "confirmationDetails", "icsDownload", "bookAnotherLabel",
    "firstNameInput", "lastNameInput", "emailInput", "phoneInput", "messageInput", "honeypotInput", "honeypotLabel",
    "localeEs", "localeEn", "progress", "progressEvent", "progressEventSeparator", "progressSchedule", "progressDetails",
    "progressEventLabel", "progressScheduleLabel", "progressDetailsLabel"
  ]

  static values = {
    slug: String,
    locale: { type: String, default: "es" },
    timezone: String,
    eventType: String,
    eventTypesUrl: String,
    availabilityUrl: String,
    bookUrl: String,
    timestamp: String,
    copy: Object
  }

  connect() {
    this.profile = null
    this.eventTypes = []
    this.selectedEventType = null
    this.currentMonth = new Date()
    this.selectedDate = null
    this.selectedSlot = null
    this.availableDays = {}
    this.guestsVisible = false
    this.syncingTimezoneSelect = false
    this.availabilityRequestId = 0
    this.availabilityAbortController = null
    this.currentStep = "eventTypes"
    this.deepLinkedEventType = this.hasEventTypeValue ? this.eventTypeValue : null
    this.tracking = this.captureTracking()
    this.parseUrlParams()
    this.detectTimezone()
    this.applyCopy()
    this.updateLocaleButtons()
    this.updateDeepLinkProgress()
    this.showStep(this.deepLinkedEventType ? "schedule" : "eventTypes")
    this.applyPrefill()
    this.loadEventTypes()
  }

  parseUrlParams() {
    const params = new URLSearchParams(window.location.search)
    this.prefill = {}
    this.knownFields = new Set()

    const lang = params.get("lang")
    if (lang && [ "es", "en" ].includes(lang)) {
      this.localeValue = lang
    }

    for (const key of [ "first_name", "last_name", "email", "phone", "message" ]) {
      const value = params.get(key)
      if (value === null || value === "") continue

      this.prefill[key] = value
      this.knownFields.add(key)
    }

    const guests = params.get("guests")
    if (guests !== null && guests !== "") {
      this.prefill.guests = guests.split(",").map((email) => email.trim()).filter(Boolean)
      if (this.prefill.guests.length) this.knownFields.add("guests")
    }

    this.hideKnown = [ "true", "1" ].includes(params.get("hide_known")?.toLowerCase())
  }

  applyPrefill() {
    if (this.prefill.first_name) this.firstNameInputTarget.value = this.prefill.first_name
    if (this.prefill.last_name) this.lastNameInputTarget.value = this.prefill.last_name
    if (this.prefill.email) this.emailInputTarget.value = this.prefill.email
    if (this.prefill.phone) this.phoneInputTarget.value = this.prefill.phone
    if (this.prefill.message) this.messageInputTarget.value = this.prefill.message
    if (this.prefill.guests?.length) this.renderGuestInputs(this.prefill.guests)
  }

  requiredFieldsComplete() {
    const firstName = this.prefill.first_name?.trim()
    const lastName = this.prefill.last_name?.trim()
    const email = this.prefill.email?.trim()

    return firstName?.length >= 2 && lastName?.length >= 2 && email?.includes("@")
  }

  captureTracking() {
    const params = new URLSearchParams(window.location.search)
    const tracking = {
      source_page: window.location.href,
      referrer: document.referrer || "",
      utm_source: params.get("utm_source") || "",
      utm_medium: params.get("utm_medium") || "",
      utm_campaign: params.get("utm_campaign") || "",
      utm_term: params.get("utm_term") || "",
      utm_content: params.get("utm_content") || ""
    }

    return Object.fromEntries(Object.entries(tracking).filter(([, value]) => value))
  }

  setLocale(event) {
    this.localeValue = event.currentTarget.dataset.locale
    const url = new URL(window.location.href)
    url.searchParams.set("lang", this.localeValue)
    history.replaceState({}, "", url)
    document.documentElement.lang = this.localeValue
    this.applyCopy()
    this.updateLocaleButtons()
    this.loadEventTypes()
    if (this.selectedEventType) {
      this.renderEventSummary()
      if (this.selectedDate && this.selectedSlot) this.renderFormSummary()
    }
  }

  applyCopy() {
    this.copy = this.localeCopy()
    this.headingChooseTarget.textContent = this.copy.chooseEvent
    this.backToTypesLabelTarget.textContent = this.copy.backToTypes
    this.backToScheduleLabelTarget.textContent = this.copy.backToSchedule
    this.timezoneLabelTarget.textContent = this.copy.timezone
    this.updateSlotsHeading()
    this.nextButtonTarget.textContent = this.copy.next
    this.firstNameLabelTarget.textContent = this.copy.firstName
    this.lastNameLabelTarget.textContent = this.copy.lastName
    this.emailLabelTarget.textContent = this.copy.email
    this.phoneLabelTarget.textContent = this.copy.phone
    this.messageLabelTarget.textContent = this.copy.message
    this.addGuestsLabelTarget.textContent = this.copy.addGuests
    this.submitLabelTarget.textContent = this.copy.schedule
    this.confirmedHeadingTarget.textContent = this.copy.confirmed
    this.icsDownloadTarget.textContent = this.copy.downloadIcs
    this.bookAnotherLabelTarget.textContent = this.copy.bookAnother
    if (this.hasConfirmHeadingTarget) this.confirmHeadingTarget.textContent = this.copy.attendeeDetails
    if (this.hasHoneypotLabelTarget) this.honeypotLabelTarget.textContent = this.copy.doNotFill
    if (this.hasProgressEventLabelTarget) this.progressEventLabelTarget.textContent = this.copy.stepEvent
    if (this.hasProgressScheduleLabelTarget) this.progressScheduleLabelTarget.textContent = this.copy.stepSchedule
    if (this.hasProgressDetailsLabelTarget) this.progressDetailsLabelTarget.textContent = this.copy.stepDetails
    this.updateProfileHomeLabel()
  }

  updateLocaleButtons() {
    if (!this.hasLocaleEsTarget || !this.hasLocaleEnTarget) return

    this.localeEsTarget.classList.toggle("is-active", this.localeValue === "es")
    this.localeEnTarget.classList.toggle("is-active", this.localeValue === "en")
  }

  progressOrder() {
    return this.deepLinkedEventType
      ? [ "schedule", "form", "confirmation" ]
      : [ "eventTypes", "schedule", "form", "confirmation" ]
  }

  updateProgress(step) {
    if (!this.hasProgressTarget) return

    const order = this.progressOrder()
    const steps = [
      { name: "eventTypes", target: "progressEventTarget" },
      { name: "schedule", target: "progressScheduleTarget" },
      { name: "form", target: "progressDetailsTarget" }
    ].filter(({ name }) => order.includes(name))
    const currentIndex = order.indexOf(step)

    for (const { name, target } of steps) {
      const element = this[target]
      if (!element) continue

      const canReturn = currentIndex > order.indexOf(name)
      element.classList.toggle("is-active", step === name)
      element.classList.toggle("is-complete", canReturn)
      if (step === name) element.setAttribute("aria-current", "step")
      else element.removeAttribute("aria-current")
      element.querySelector(".public-booking-progress-jump")?.toggleAttribute("disabled", !canReturn)
    }

    this.progressTarget.classList.toggle("hidden", step === "confirmation")
  }

  updateDeepLinkProgress() {
    const deepLink = Boolean(this.deepLinkedEventType)

    if (this.hasProgressEventTarget) {
      this.progressEventTarget.classList.toggle("hidden", deepLink)
    }
    if (this.hasProgressEventSeparatorTarget) {
      this.progressEventSeparatorTarget.classList.toggle("hidden", deepLink)
    }

    const scheduleNumber = this.progressScheduleTarget?.querySelector(".public-booking-progress-number")
    const detailsNumber = this.progressDetailsTarget?.querySelector(".public-booking-progress-number")
    if (scheduleNumber) scheduleNumber.textContent = deepLink ? "1" : "2"
    if (detailsNumber) detailsNumber.textContent = deepLink ? "2" : "3"
  }

  async loadEventTypes() {
    const response = await fetch(`${this.eventTypesUrlValue}?lang=${this.localeValue}`)
    const data = await response.json()
    this.profile = data.profile
    this.eventTypes = data.event_types
    this.renderProfile()
    this.renderEventTypes()
    if (this.deepLinkedEventType) {
      this.selectEventTypeBySlug(this.deepLinkedEventType, { updateUrl: false })
    }
  }

  renderProfile() {
    if (!this.profile) return
    this.profileTarget.innerHTML = `
      ${this.profile.avatar_url ? `<img src="${this.escape(this.profile.avatar_url)}" alt="" class="public-booking-avatar">` : ""}
      <div class="min-w-0 flex-1">
        <p class="public-booking-host-name">${this.escape(this.profile.name)}</p>
        ${this.profile.welcome_message ? `<p class="public-booking-welcome">${this.escape(this.profile.welcome_message)}</p>` : ""}
      </div>
      ${this.profile.logo_url ? `<img src="${this.escape(this.profile.logo_url)}" alt="" class="public-booking-logo">` : ""}
    `
    this.updateProfileHomeLabel()
  }

  updateProfileHomeLabel() {
    if (!this.hasProfileTarget || !this.copy?.backToStart) return

    const name = this.profile?.name
    this.profileTarget.setAttribute("aria-label", name ? `${name}. ${this.copy.backToStart}` : this.copy.backToStart)
  }

  profileKeydown(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    event.preventDefault()
    this.goToFirstStep()
  }

  goToFirstStep() {
    if (this.currentStep === "eventTypes" && !this.deepLinkedEventType) return

    if (this.currentStep === "confirmation") this.resetDraftForm()
    this.deepLinkedEventType = null
    this.backToEventTypes()
    this.updateDeepLinkProgress()
  }

  goToStep(event) {
    const step = event.currentTarget.dataset.step
    const order = this.progressOrder()
    const targetIndex = order.indexOf(step)
    if (targetIndex < 0 || targetIndex >= order.indexOf(this.currentStep)) return

    if (step === "eventTypes") this.backToEventTypes()
    else if (step === "schedule") this.backToSchedule()
  }

  renderEventTypes() {
    this.eventTypeGridTarget.innerHTML = this.eventTypes.map((eventType) => `
      <button type="button" class="public-booking-event-card border-l-4 ${this.borderClass(eventType.color)}"
              data-action="booking#selectEventType" data-slug="${eventType.slug}">
        <div class="public-booking-event-card-header">
          <span class="public-booking-event-icon">${this.locationIcon(eventType.location_type)}</span>
          <div class="min-w-0">
            <p class="public-booking-event-name">${this.escape(eventType.name)}</p>
            <p class="public-booking-event-meta">${eventType.duration_minutes} ${this.copy.minutes}</p>
          </div>
        </div>
        ${eventType.description ? `<p class="public-booking-event-desc">${this.escape(eventType.description)}</p>` : ""}
      </button>
    `).join("")
  }

  selectEventType(event) {
    this.selectEventTypeBySlug(event.currentTarget.dataset.slug, { updateUrl: true })
  }

  selectEventTypeBySlug(slug, { updateUrl = true } = {}) {
    const eventType = this.eventTypes.find((item) => item.slug === slug)
    if (!eventType) {
      this.deepLinkedEventType = null
      this.updateDeepLinkProgress()
      this.updateBackToTypesVisibility()
      this.showStep("eventTypes")
      return
    }

    this.selectedEventType = eventType
    this.selectedDate = null
    this.selectedSlot = null
    this.availableDays = {}
    this.showStep("schedule")
    this.renderEventSummary()
    this.renderTimezoneSelect()
    this.renderCalendar()
    this.hideScheduleError()
    this.loadMonthAvailability()
    if (updateUrl) this.updateEventTypeUrl(slug)
    this.updateBackToTypesVisibility()
    this.updateDeepLinkProgress()
    if (this.deepLinkedEventType) this.updateProgress("schedule")
  }

  backToEventTypes() {
    this.selectedEventType = null
    this.selectedDate = null
    this.selectedSlot = null
    this.showStep("eventTypes")
    this.updatePageUrl()
    this.updateBackToTypesVisibility()
  }

  backToSchedule() {
    this.showStep("schedule")
  }

  async loadMonthAvailability() {
    const requestId = ++this.availabilityRequestId
    this.showScheduleLoading(true)
    try {
      const month = `${this.currentMonth.getFullYear()}-${String(this.currentMonth.getMonth() + 1).padStart(2, "0")}`
      const params = new URLSearchParams({
        event_type: this.selectedEventType.slug,
        month,
        timezone: this.timezoneValue,
        lang: this.localeValue
      })
      const { response, data } = await this.fetchAvailability(params)
      if (requestId !== this.availabilityRequestId) return

      if (!response.ok) {
        this.showScheduleError(data.message || data.error || this.copy.calendarUnavailable, data.help_url)
        this.availableDays = {}
        this.renderCalendar()
        return
      }

      if (data.warning) {
        this.showScheduleWarning(data.warning)
      } else {
        this.hideScheduleError()
      }

      this.availableDays = Object.fromEntries((data.days || []).map((day) => [ day.date, day.available ]))
      this.renderCalendar()
    } catch (error) {
      if (error.name === "AbortError") return
      if (requestId !== this.availabilityRequestId) return
      this.showScheduleError(this.copy.calendarUnavailable)
      this.availableDays = {}
      this.renderCalendar()
    } finally {
      if (requestId === this.availabilityRequestId) {
        this.showScheduleLoading(false)
      }
    }
  }

  renderCalendar() {
    const year = this.currentMonth.getFullYear()
    const month = this.currentMonth.getMonth()
    this.monthLabelTarget.textContent = this.currentMonth.toLocaleDateString(this.localeValue, { month: "long", year: "numeric" })
    const firstDay = new Date(year, month, 1)
    const startOffset = (firstDay.getDay() + 6) % 7
    const daysInMonth = new Date(year, month + 1, 0).getDate()

    let html = this.copy.weekdays.map((label) => `<div class="public-booking-calendar-weekday">${label}</div>`).join("")
    for (let i = 0; i < startOffset; i++) html += `<div></div>`

    for (let day = 1; day <= daysInMonth; day++) {
      const iso = `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`
      const available = this.availableDays[iso]
      const selected = this.selectedDate === iso
      const disabled = !available
      const stateClass = selected ? "is-selected" : available ? "is-available" : "is-unavailable"
      html += `
        <button type="button"
                class="public-booking-day ${stateClass}"
                ${disabled ? "disabled" : `data-action="booking#selectDate" data-date="${iso}"`}>
          ${day}
        </button>
      `
    }
    this.calendarGridTarget.innerHTML = html
  }

  prevMonth() {
    this.currentMonth = new Date(this.currentMonth.getFullYear(), this.currentMonth.getMonth() - 1, 1)
    this.loadMonthAvailability()
  }

  nextMonth() {
    this.currentMonth = new Date(this.currentMonth.getFullYear(), this.currentMonth.getMonth() + 1, 1)
    this.loadMonthAvailability()
  }

  async selectDate(event) {
    this.selectedDate = event.currentTarget.dataset.date
    this.selectedSlot = null
    this.nextButtonTarget.classList.add("hidden")
    this.renderCalendar()
    await this.loadSlots()
  }

  async loadSlots() {
    const requestId = ++this.availabilityRequestId
    this.slotsListTarget.innerHTML = `<p class="public-booking-slot-loading">${this.copy.loadingAvailability}</p>`
    try {
      const params = new URLSearchParams({
        event_type: this.selectedEventType.slug,
        date: this.selectedDate,
        timezone: this.timezoneValue,
        lang: this.localeValue
      })
      const { response, data } = await this.fetchAvailability(params)
      if (requestId !== this.availabilityRequestId) return

      if (!response.ok) {
        this.showScheduleError(data.message || data.error || this.copy.calendarUnavailable, data.help_url)
        this.slotsListTarget.innerHTML = ""
        return
      }

      if (data.warning) {
        this.showScheduleWarning(data.warning)
      }

      const slots = data.slots || []
      if (data.timezone && data.timezone !== this.timezoneValue) return
      if (!slots.length) {
        this.slotsListTarget.innerHTML = `<p class="public-booking-slot-empty">${this.copy.noSlots}</p>`
        return
      }

      this.slotsListTarget.innerHTML = slots.map((slot) => `
        <button type="button" class="public-booking-slot ${this.selectedSlot === slot ? "is-selected" : ""}"
                data-action="booking#selectSlot" data-slot="${slot}">${slot}</button>
      `).join("")
    } catch (error) {
      if (error.name === "AbortError") return
      if (requestId !== this.availabilityRequestId) return
      this.showScheduleError(this.copy.calendarUnavailable)
      this.slotsListTarget.innerHTML = ""
    }
  }

  selectSlot(event) {
    this.selectedSlot = event.currentTarget.dataset.slot
    this.loadSlots()
    this.nextButtonTarget.classList.remove("hidden")
  }

  goToForm() {
    this.showStep("form")
    this.renderFormSummary()
    this.formErrorTarget.classList.add("hidden")

    if (this.hideKnown && this.requiredFieldsComplete()) {
      this.showConfirmOnly()
    } else {
      this.showFormStep()
    }
  }

  showConfirmOnly() {
    this.formFieldsTarget.classList.add("hidden")
    this.confirmPanelTarget.classList.remove("hidden")
    this.renderConfirmSummary()
  }

  showFormStep() {
    this.formFieldsTarget.classList.remove("hidden")
    this.confirmPanelTarget.classList.add("hidden")
    this.applyFieldVisibility()
  }

  applyFieldVisibility() {
    const fieldTargets = {
      first_name: "firstNameFieldTarget",
      last_name: "lastNameFieldTarget",
      email: "emailFieldTarget",
      phone: "phoneFieldTarget",
      message: "messageFieldTarget",
      guests: "guestsSectionTarget"
    }

    for (const [ key, targetName ] of Object.entries(fieldTargets)) {
      const target = this[targetName]
      if (!target) continue

      target.classList.toggle("hidden", this.hideKnown && this.knownFields.has(key))
    }
  }

  renderConfirmSummary() {
    const lines = [
      `<p><strong>${this.escape(this.firstNameInputTarget.value)} ${this.escape(this.lastNameInputTarget.value)}</strong></p>`,
      `<p>${this.escape(this.emailInputTarget.value)}</p>`
    ]

    const phone = this.phoneInputTarget.value.trim()
    if (phone) lines.push(`<p>${this.escape(phone)}</p>`)

    const message = this.messageInputTarget.value.trim()
    if (message) lines.push(`<p class="text-ink-soft">${this.escape(message)}</p>`)

    const guests = this.collectGuestEmails()
    if (guests.length) {
      lines.push(`<p class="text-ink-faint">${this.copy.guestsLabel}: ${guests.map((email) => this.escape(email)).join(", ")}</p>`)
    }

    this.confirmSummaryTarget.innerHTML = lines.join("")
  }

  renderEventSummary() {
    if (!this.selectedEventType) return
    this.eventSummaryTarget.innerHTML = `
      <p class="public-booking-summary-name">${this.escape(this.selectedEventType.name)}</p>
      <p class="public-booking-summary-meta">${this.selectedEventType.duration_minutes} ${this.copy.minutes}</p>
      ${this.selectedEventType.description ? `<p class="public-booking-summary-desc">${this.escape(this.selectedEventType.description)}</p>` : ""}
    `
  }

  renderFormSummary() {
    this.formSummaryTarget.innerHTML = `
      <p class="public-booking-summary-name">${this.escape(this.selectedEventType.name)}</p>
      <p class="public-booking-summary-meta">${this.escape(this.formatDateTime(this.selectedDate, this.selectedSlot))}</p>
    `
  }

  toggleGuests() {
    this.guestsVisible = !this.guestsVisible
    if (this.guestsVisible) {
      this.renderGuestInputs()
    } else {
      this.guestsFieldsTarget.classList.add("hidden")
      this.guestsFieldsTarget.innerHTML = ""
    }
  }

  renderGuestInputs(prefilledEmails = []) {
    this.guestsVisible = true
    this.guestsFieldsTarget.classList.remove("hidden")
    this.guestsFieldsTarget.innerHTML = Array.from({ length: 5 }, (_, index) => {
      const value = prefilledEmails[index] ? ` value="${this.escape(prefilledEmails[index])}"` : ""
      return `<input type="email" name="guest_${index}" placeholder="${this.copy.guest} ${index + 1}" class="input w-full guest-email"${value}>`
    }).join("")
  }

  collectGuestEmails() {
    return Array.from(this.element.querySelectorAll(".guest-email"))
      .map((input) => input.value.trim())
      .filter(Boolean)
  }

  buildPayload() {
    return {
      event_type: this.selectedEventType.slug,
      datetime: `${this.selectedDate}T${this.selectedSlot}:00`,
      timezone: this.timezoneValue,
      lang: this.localeValue,
      first_name: this.firstNameInputTarget.value.trim(),
      last_name: this.lastNameInputTarget.value.trim(),
      email: this.emailInputTarget.value.trim(),
      phone: this.phoneInputTarget.value.trim(),
      message: this.messageInputTarget.value.trim(),
      guests: this.collectGuestEmails(),
      _ts: this.timestampValue,
      _honeypot: this.hasHoneypotInputTarget ? this.honeypotInputTarget.value : "",
      ...this.tracking
    }
  }

  async submitBooking(event) {
    event.preventDefault()
    this.formErrorTarget.classList.add("hidden")
    this.submitLabelTarget.textContent = this.copy.scheduling
    this.submitLabelTarget.disabled = true

    const payload = this.buildPayload()

    const response = await fetch(this.bookUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify(payload)
    })

    this.submitLabelTarget.disabled = false
    this.submitLabelTarget.textContent = this.copy.schedule

    if (response.status === 409) {
      this.formErrorTarget.textContent = this.copy.slotTaken
      this.formErrorTarget.classList.remove("hidden")
      return
    }

    if (!response.ok) {
      const data = await response.json()
      this.formErrorTarget.textContent = data.error || this.copy.genericError
      this.formErrorTarget.classList.remove("hidden")
      return
    }

    const data = await response.json()
    if (data.redirect_url) {
      window.location.assign(data.redirect_url)
      return
    }
    this.showConfirmation(data)
  }

  showConfirmation(data) {
    this.showStep("confirmation")
    const whenLabel = data.display_starts_at ||
      this.formatInstantInZone(data.starts_at, data.timezone)
    const lines = [
      `<p class="public-booking-summary-name">${this.escape(data.event_type.name)}</p>`,
      `<p class="public-booking-summary-meta">${this.escape(whenLabel)}</p>`,
      `<p class="public-booking-summary-desc">${data.event_type.duration_minutes} ${this.copy.minutes}</p>`
    ]
    if (data.meet_link) {
      lines.push(`<p><a href="${this.escape(data.meet_link)}" class="text-accent underline" target="_blank" rel="noopener">${this.copy.meetLink}</a></p>`)
    }
    if (data.location_address) {
      lines.push(`<p>${this.copy.location}: ${this.escape(data.location_address)}</p>`)
    }
    if (data.reminder_minutes_before) {
      lines.push(`<p class="text-sm text-ink-faint">${this.reminderNotice(data.reminder_minutes_before)}</p>`)
    }
    if (data.confirmation_email) {
      lines.push(`<p class="text-sm text-ink-faint">${this.confirmationEmailNotice(data.attendee_email)}</p>`)
    }
    this.confirmationDetailsTarget.innerHTML = lines.join("")
    this.icsDownloadTarget.href = this.buildIcs(data)
  }

  buildIcs(data) {
    const start = this.icsUtcStamp(data.starts_at)
    const end = this.icsUtcStamp(data.ends_at)
    const body = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Cream//Booking//EN",
      "BEGIN:VEVENT",
      `DTSTART:${start}`,
      `DTEND:${end}`,
      `SUMMARY:${data.event_type.name}`,
      data.meet_link ? `URL:${data.meet_link}` : "",
      "END:VEVENT",
      "END:VCALENDAR"
    ].filter(Boolean).join("\r\n")
    return `data:text/calendar;charset=utf-8,${encodeURIComponent(body)}`
  }

  resetDraftForm() {
    this.formTarget.reset()
    this.applyPrefill()
    this.formFieldsTarget.classList.remove("hidden")
    this.confirmPanelTarget.classList.add("hidden")
    this.applyFieldVisibility()
    this.formErrorTarget.classList.add("hidden")
  }

  restart() {
    this.selectedDate = null
    this.selectedSlot = null
    this.resetDraftForm()

    if (this.deepLinkedEventType) {
      this.selectEventTypeBySlug(this.deepLinkedEventType, { updateUrl: false })
      return
    }

    this.selectedEventType = null
    this.showStep("eventTypes")
    this.loadEventTypes()
  }

  updateEventTypeUrl(eventTypeSlug) {
    const url = new URL(window.location.href)
    url.pathname = `/b/${this.slugValue}/${eventTypeSlug}`
    history.replaceState({}, "", url)
  }

  updatePageUrl() {
    const url = new URL(window.location.href)
    url.pathname = `/b/${this.slugValue}`
    history.replaceState({}, "", url)
  }

  updateBackToTypesVisibility() {
    if (!this.hasBackToTypesWrapTarget) return

    this.backToTypesWrapTarget.classList.toggle("hidden", Boolean(this.deepLinkedEventType))
  }

  timezoneChanged() {
    if (this.syncingTimezoneSelect) return

    this.timezoneValue = this.timezoneSelectTarget.value
    this.selectedSlot = null
    if (this.hasNextButtonTarget) this.nextButtonTarget.classList.add("hidden")
    this.updateSlotsHeading()
    if (this.selectedEventType) this.loadMonthAvailability()
    if (this.selectedDate) this.loadSlots()
  }

  updateSlotsHeading() {
    if (!this.hasSlotsHeadingTarget) return

    this.slotsHeadingTarget.textContent = this.copy.availableSlotsInZone
      .replace("%{timezone}", this.timezoneValue)
  }

  detectTimezone() {
    try {
      this.timezoneValue = Intl.DateTimeFormat().resolvedOptions().timeZone || this.timezoneValue
    } catch (_error) {
      // keep default
    }
  }

  renderTimezoneSelect() {
    const zones = [ this.timezoneValue, "Europe/Madrid", "Europe/London", "America/New_York", "America/Los_Angeles" ]
    const unique = [ ...new Set(zones.filter(Boolean)) ]
    this.syncingTimezoneSelect = true
    this.timezoneSelectTarget.innerHTML = unique.map((zone) =>
      `<option value="${zone}" ${zone === this.timezoneValue ? "selected" : ""}>${zone}</option>`
    ).join("")
    this.timezoneSelectTarget.value = this.timezoneValue
    this.syncingTimezoneSelect = false
  }

  showScheduleError(message, helpUrl = null) {
    if (!this.hasScheduleErrorTarget) return

    const helpLink = helpUrl
      ? ` <a href="${this.escape(helpUrl)}" class="text-accent underline" target="_blank" rel="noopener">${this.copy.enableCalendarApi}</a>`
      : ""
    this.scheduleErrorTarget.className = "public-booking-alert is-error"
    this.scheduleErrorTarget.innerHTML = `${this.escape(message)}${helpLink}`
    this.scheduleErrorTarget.classList.remove("hidden")
  }

  showScheduleWarning(message) {
    if (!this.hasScheduleErrorTarget) return

    this.scheduleErrorTarget.className = "public-booking-alert is-warning"
    this.scheduleErrorTarget.textContent = `${this.copy.calendarEstimated} ${message}`
    this.scheduleErrorTarget.classList.remove("hidden")
  }

  hideScheduleError() {
    if (!this.hasScheduleErrorTarget) return

    this.scheduleErrorTarget.textContent = ""
    this.scheduleErrorTarget.classList.add("hidden")
  }

  async fetchAvailability(params) {
    if (this.availabilityAbortController) {
      this.availabilityAbortController.abort()
    }

    this.availabilityAbortController = new AbortController()
    const timeoutId = setTimeout(() => this.availabilityAbortController.abort(), 20000)

    try {
      const response = await fetch(`${this.availabilityUrlValue}?${params}`, {
        signal: this.availabilityAbortController.signal
      })
      const data = await response.json()
      return { response, data }
    } finally {
      clearTimeout(timeoutId)
    }
  }

  showScheduleLoading(loading) {
    this.calendarGridTarget.classList.toggle("opacity-50", loading)
    this.calendarGridTarget.classList.toggle("pointer-events-none", loading)
  }

  showStep(step) {
    this.currentStep = step
    this.stepEventTypesTarget.classList.toggle("hidden", step !== "eventTypes")
    this.stepScheduleTarget.classList.toggle("hidden", step !== "schedule")
    this.stepFormTarget.classList.toggle("hidden", step !== "form")
    this.stepConfirmationTarget.classList.toggle("hidden", step !== "confirmation")
    this.updateProgress(step)
  }

  formatDateTime(dateStr, timeStr) {
    if (!dateStr || !timeStr) return ""

    const datetime = this.formatCalendarDateLabel(dateStr)
    return this.copy.scheduleSummary
      .replace("%{datetime}", `${datetime}, ${timeStr}`)
      .replace("%{timezone}", this.timezoneValue)
  }

  icsUtcStamp(iso8601) {
    const stamp = new Date(iso8601).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z")
    return stamp.endsWith("Z") ? stamp : `${stamp}Z`
  }

  formatCalendarDateLabel(dateStr) {
    const [ year, month, day ] = dateStr.split("-").map(Number)
    const anchor = new Date(Date.UTC(year, month - 1, day, 12, 0))
    return anchor.toLocaleDateString(this.localeValue, {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: "UTC"
    })
  }

  formatInstantInZone(iso8601, timeZone) {
    if (!iso8601 || !timeZone) return ""

    const formatted = new Intl.DateTimeFormat(this.localeValue, {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      timeZone
    }).format(new Date(iso8601))

    return this.copy.scheduleSummary
      .replace("%{datetime}", formatted)
      .replace("%{timezone}", timeZone)
  }

  reminderNotice(minutes) {
    return this.copy.reminderNotice.replace("%{minutes}", minutes)
  }

  confirmationEmailNotice(email) {
    return this.copy.confirmationEmailNotice.replace("%{email}", this.escape(email))
  }

  locationIcon(type) {
    return LOCATION_ICONS[type] || LOCATION_ICONS.to_be_decided
  }

  escape(text) {
    return String(text || "").replace(/[&<>"']/g, (char) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[char])
  }

  borderClass(color) {
    return {
      hoki: "border-hoki-500",
      copperfield: "border-copperfield-500",
      golden: "border-golden-500",
      chicago: "border-chicago-500",
      green: "border-green-500",
      blue: "border-blue-500"
    }[color] || "border-accent"
  }

  localeCopy() {
    const bundles = this.copyValue || {}
    return bundles[this.localeValue] || bundles.es || {}
  }
}
