import { Controller } from "@hotwired/stimulus"

const COPY = {
  es: {
    chooseEvent: "Elige un tipo de reunión",
    backToTypes: "← Volver a tipos de evento",
    backToSchedule: "← Volver al calendario",
    timezone: "Zona horaria",
    availableSlots: "Horarios disponibles",
    next: "Siguiente",
    firstName: "Nombre",
    lastName: "Apellidos",
    email: "Email",
    phone: "Teléfono (opcional)",
    message: "¿De qué quieres que hablemos?",
    addGuests: "Añadir invitados",
    guest: "Invitado",
    schedule: "Programar evento",
    scheduling: "Programando…",
    confirmed: "¡Reunión programada!",
    emailNotice: "Recibirás una invitación por email.",
    meetLink: "Enlace de Google Meet",
    location: "Ubicación",
    downloadIcs: "Descargar .ics",
    bookAnother: "Agendar otra reunión",
    attendeeDetails: "Datos del asistente",
    guestsLabel: "Invitados",
    minutes: "min",
    slotTaken: "Ese horario ya no está disponible. Elige otro.",
    calendarUnavailable: "No se pudo consultar la disponibilidad del calendario.",
    calendarEstimated: "Mostrando horarios según la agenda configurada. Google Calendar no respondió; algunos huecos pueden estar ocupados.",
    loadingAvailability: "Consultando disponibilidad…",
    noSlots: "No hay horarios disponibles este día.",
    weekdays: [ "L", "M", "X", "J", "V", "S", "D" ],
    locationIcons: { google_meet: "📹", physical: "📍", to_be_decided: "📞" }
  },
  en: {
    chooseEvent: "Choose an event type",
    backToTypes: "← Back to event types",
    backToSchedule: "← Back to calendar",
    timezone: "Timezone",
    availableSlots: "Available times",
    next: "Next",
    firstName: "First name",
    lastName: "Last name",
    email: "Email",
    phone: "Phone (optional)",
    message: "What would you like to discuss?",
    addGuests: "Add guests",
    guest: "Guest",
    schedule: "Schedule event",
    scheduling: "Scheduling…",
    confirmed: "Event scheduled!",
    emailNotice: "You will receive an email invitation.",
    meetLink: "Google Meet link",
    location: "Location",
    downloadIcs: "Download .ics",
    bookAnother: "Schedule another meeting",
    attendeeDetails: "Attendee details",
    guestsLabel: "Guests",
    minutes: "min",
    slotTaken: "That time is no longer available. Please choose another.",
    calendarUnavailable: "Could not load calendar availability.",
    calendarEstimated: "Showing times from the configured schedule. Google Calendar did not respond; some slots may already be booked.",
    loadingAvailability: "Loading availability…",
    noSlots: "No available times on this day.",
    weekdays: [ "M", "T", "W", "T", "F", "S", "S" ],
    locationIcons: { google_meet: "📹", physical: "📍", to_be_decided: "📞" }
  }
}

export default class extends Controller {
  static targets = [
    "profile", "headingChoose", "eventTypeGrid", "stepEventTypes", "stepSchedule", "stepForm", "stepConfirmation",
    "backToTypesLabel", "backToScheduleLabel", "monthLabel", "calendarGrid", "scheduleError", "timezoneLabel", "timezoneSelect",
    "eventSummary", "slotsHeading", "slotsList", "nextButton", "form", "formFields", "formSummary", "formError",
    "firstNameField", "lastNameField", "emailField", "phoneField", "messageField", "guestsSection",
    "confirmPanel", "confirmHeading", "confirmSummary",
    "firstNameLabel", "lastNameLabel", "emailLabel", "phoneLabel", "messageLabel", "addGuestsLabel", "guestsFields",
    "submitLabel", "confirmedHeading", "confirmationDetails", "icsDownload", "bookAnotherLabel",
    "firstNameInput", "lastNameInput", "emailInput", "phoneInput", "messageInput", "honeypotInput"
  ]

  static values = {
    slug: String,
    locale: { type: String, default: "es" },
    timezone: String,
    eventTypesUrl: String,
    availabilityUrl: String,
    bookUrl: String,
    timestamp: String
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
    this.tracking = this.captureTracking()
    this.parseUrlParams()
    this.detectTimezone()
    this.applyCopy()
    this.applyPrefill()
    this.loadEventTypes()
  }

  parseUrlParams() {
    const params = new URLSearchParams(window.location.search)
    this.prefill = {}
    this.knownFields = new Set()

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
    this.applyCopy()
    this.loadEventTypes()
  }

  applyCopy() {
    this.copy = COPY[this.localeValue] || COPY.es
    this.headingChooseTarget.textContent = this.copy.chooseEvent
    this.backToTypesLabelTarget.textContent = this.copy.backToTypes
    this.backToScheduleLabelTarget.textContent = this.copy.backToSchedule
    this.timezoneLabelTarget.textContent = this.copy.timezone
    this.slotsHeadingTarget.textContent = this.copy.availableSlots
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
  }

  async loadEventTypes() {
    const response = await fetch(`${this.eventTypesUrlValue}?lang=${this.localeValue}`)
    const data = await response.json()
    this.profile = data.profile
    this.eventTypes = data.event_types
    if (data.timezone) this.timezoneValue = data.timezone
    this.renderProfile()
    this.renderEventTypes()
  }

  renderProfile() {
    if (!this.profile) return
    this.profileTarget.innerHTML = `
      ${this.profile.avatar_url ? `<img src="${this.profile.avatar_url}" alt="" class="size-14 rounded-full object-cover">` : ""}
      <div class="min-w-0">
        <p class="font-display text-xl font-semibold truncate">${this.escape(this.profile.name)}</p>
        ${this.profile.welcome_message ? `<p class="text-sm text-ink-soft">${this.escape(this.profile.welcome_message)}</p>` : ""}
      </div>
      ${this.profile.logo_url ? `<img src="${this.profile.logo_url}" alt="" class="h-8 ml-auto">` : ""}
    `
  }

  renderEventTypes() {
    this.eventTypeGridTarget.innerHTML = this.eventTypes.map((eventType) => `
      <button type="button" class="card p-4 text-left hover:border-accent transition-colors border-l-4 ${this.borderClass(eventType.color)}"
              data-action="booking#selectEventType" data-slug="${eventType.slug}">
        <div class="flex items-start gap-2">
          <span>${this.copy.locationIcons[eventType.location_type] || ""}</span>
          <div>
            <p class="font-semibold">${this.escape(eventType.name)}</p>
            <p class="text-sm text-ink-faint">${eventType.duration_minutes} ${this.copy.minutes}</p>
            <p class="text-sm text-ink-soft mt-1">${this.escape(eventType.description || "")}</p>
          </div>
        </div>
      </button>
    `).join("")
  }

  selectEventType(event) {
    const slug = event.currentTarget.dataset.slug
    this.selectedEventType = this.eventTypes.find((item) => item.slug === slug)
    this.selectedDate = null
    this.selectedSlot = null
    this.availableDays = {}
    this.showStep("schedule")
    this.renderEventSummary()
    this.renderTimezoneSelect()
    this.renderCalendar()
    this.hideScheduleError()
    this.loadMonthAvailability()
  }

  backToEventTypes() {
    this.showStep("eventTypes")
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

    let html = this.copy.weekdays.map((label) => `<div class="text-ink-faint font-medium py-1">${label}</div>`).join("")
    for (let i = 0; i < startOffset; i++) html += `<div></div>`

    for (let day = 1; day <= daysInMonth; day++) {
      const iso = `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`
      const available = this.availableDays[iso]
      const selected = this.selectedDate === iso
      const disabled = !available
      html += `
        <button type="button"
                class="rounded-md py-2 ${selected ? "bg-accent text-on-dark" : available ? "bg-accent-soft hover:bg-accent/20" : "text-ink-faint opacity-40 cursor-not-allowed"}"
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
    this.slotsListTarget.innerHTML = `<p class="text-sm text-ink-faint">${this.copy.loadingAvailability}</p>`
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
      if (!slots.length) {
        this.slotsListTarget.innerHTML = `<p class="text-sm text-ink-faint">${this.copy.noSlots}</p>`
        return
      }

      this.slotsListTarget.innerHTML = slots.map((slot) => `
        <button type="button" class="btn-secondary ${this.selectedSlot === slot ? "!bg-accent !text-on-dark" : ""}"
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
      <p class="font-semibold">${this.escape(this.selectedEventType.name)}</p>
      <p class="text-sm text-ink-faint">${this.selectedEventType.duration_minutes} ${this.copy.minutes}</p>
      <p class="text-sm text-ink-soft">${this.escape(this.selectedEventType.description || "")}</p>
    `
  }

  renderFormSummary() {
    this.formSummaryTarget.innerHTML = `
      <p class="font-semibold">${this.escape(this.selectedEventType.name)}</p>
      <p class="text-sm">${this.selectedDate} ${this.selectedSlot}</p>
      <p class="text-sm text-ink-faint">${this.timezoneValue}</p>
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
      this.formErrorTarget.textContent = data.error || "Error"
      this.formErrorTarget.classList.remove("hidden")
      return
    }

    const data = await response.json()
    this.showConfirmation(data)
  }

  showConfirmation(data) {
    this.showStep("confirmation")
    const lines = [
      `<p><strong>${this.escape(data.event_type.name)}</strong></p>`,
      `<p>${new Date(data.starts_at).toLocaleString(this.localeValue)} (${data.timezone})</p>`,
      `<p>${data.event_type.duration_minutes} ${this.copy.minutes}</p>`
    ]
    if (data.meet_link) lines.push(`<p><a href="${data.meet_link}" class="text-accent underline" target="_blank" rel="noopener">${this.copy.meetLink}</a></p>`)
    if (data.location_address) lines.push(`<p>${this.copy.location}: ${this.escape(data.location_address)}</p>`)
    lines.push(`<p class="text-sm text-ink-faint">${this.copy.emailNotice}</p>`)
    this.confirmationDetailsTarget.innerHTML = lines.join("")
    this.icsDownloadTarget.href = this.buildIcs(data)
  }

  buildIcs(data) {
    const start = new Date(data.starts_at).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "")
    const end = new Date(data.ends_at).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "")
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

  restart() {
    this.selectedEventType = null
    this.selectedDate = null
    this.selectedSlot = null
    this.formTarget.reset()
    this.applyPrefill()
    this.formFieldsTarget.classList.remove("hidden")
    this.confirmPanelTarget.classList.add("hidden")
    this.applyFieldVisibility()
    this.showStep("eventTypes")
    this.loadEventTypes()
  }

  timezoneChanged() {
    if (this.syncingTimezoneSelect) return

    this.timezoneValue = this.timezoneSelectTarget.value
    if (this.selectedEventType) this.loadMonthAvailability()
    if (this.selectedDate) this.loadSlots()
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
      ? ` <a href="${this.escape(helpUrl)}" class="text-accent underline" target="_blank" rel="noopener">Activar Google Calendar API</a>`
      : ""
    this.scheduleErrorTarget.className = "text-sm text-red-600 mt-3"
    this.scheduleErrorTarget.innerHTML = `${this.escape(message)}${helpLink}`
    this.scheduleErrorTarget.classList.remove("hidden")
  }

  showScheduleWarning(message) {
    if (!this.hasScheduleErrorTarget) return

    this.scheduleErrorTarget.className = "text-sm text-golden-800 bg-golden-100 rounded-md px-3 py-2 mt-3"
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
    this.stepEventTypesTarget.classList.toggle("hidden", step !== "eventTypes")
    this.stepScheduleTarget.classList.toggle("hidden", step !== "schedule")
    this.stepFormTarget.classList.toggle("hidden", step !== "form")
    this.stepConfirmationTarget.classList.toggle("hidden", step !== "confirmation")
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
}
