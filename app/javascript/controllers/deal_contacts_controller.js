import { Controller } from "@hotwired/stimulus"

// Keeps the deal's contacts in sync with the chosen company and partner: lists
// their people, and lets you create a new contact in the client company without leaving.
export default class extends Controller {
  static targets = ["companySelect", "partnerSelect", "select", "dialog", "firstName", "lastName", "email", "phone", "source", "broughtByRow", "broughtBy", "firstContactOn", "notice", "error", "submit"]
  static values = {
    peopleUrl: String,
    pickCompanyError: String,
    selectTeamMemberError: String,
    networkError: String,
    createFailed: String
  }

  connect() {
    this.toggleBroughtBy()
  }

  companyChanged() {
    this.refreshContacts()
  }

  async refreshContacts() {
    const companyId = this.companySelectTarget.value
    const partnerId = this.hasPartnerSelectTarget ? this.partnerSelectTarget.value : null
    const selectedIds = Array.from(this.selectTarget.selectedOptions).map(option => option.value)
    this.hide(this.noticeTarget)

    const companyIds = [ companyId, partnerId ].filter(Boolean)
    if (companyIds.length === 0) {
      this.selectTarget.innerHTML = ""
      return
    }

    try {
      const peopleArrays = await Promise.all(companyIds.map(id => this.fetchPeopleForCompany(id)))
      const seen = new Set()
      const people = []
      for (const list of peopleArrays) {
        for (const person of list) {
          if (!seen.has(person.id)) {
            seen.add(person.id)
            people.push(person)
          }
        }
      }
      people.sort((a, b) => a.name.localeCompare(b.name))
      this.selectTarget.innerHTML = ""
      people.forEach(person => {
        const option = new Option(person.name, person.id)
        if (selectedIds.includes(String(person.id))) option.selected = true
        this.selectTarget.add(option)
      })
    } catch { /* ignore */ }
  }

  async fetchPeopleForCompany(id) {
    const res = await fetch(`${this.peopleUrlValue}.json?company_id=${id}`, { headers: { Accept: "application/json" } })
    if (!res.ok) return []
    return await res.json()
  }

  open(event) {
    event.preventDefault()
    if (!this.companySelectTarget.value) {
      this.noticeTarget.textContent = this.pickCompanyErrorValue
      this.show(this.noticeTarget)
      return
    }
    this.hide(this.errorTarget)
    this.firstNameTarget.value = ""
    this.lastNameTarget.value = ""
    this.emailTarget.value = ""
    this.phoneTarget.value = ""
    this.sourceTarget.value = ""
    this.broughtByTarget.value = ""
    this.toggleBroughtBy()
    this.firstContactOnTarget.value = ""
    this.dialogTarget.showModal()
    this.firstNameTarget.focus()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  sourceChanged() {
    this.toggleBroughtBy()
  }

  toggleBroughtBy() {
    const show = this.sourceTarget.value === "team_member"
    this.broughtByRowTarget.classList.toggle("hidden", !show)
    if (!show) this.broughtByTarget.value = ""
  }

  async create(event) {
    event.preventDefault()
    const first = this.firstNameTarget.value.trim()
    const last = this.lastNameTarget.value.trim()
    if (!first) { this.firstNameTarget.focus(); return }
    if (this.sourceTarget.value === "team_member" && !this.broughtByTarget.value) {
      this.error(this.selectTeamMemberErrorValue)
      this.broughtByTarget.focus()
      return
    }

    this.submitTarget.disabled = true
    try {
      const person = {
        first_name: first,
        last_name: last,
        company_id: this.companySelectTarget.value,
        email: this.emailTarget.value.trim(),
        phone: this.phoneTarget.value.trim(),
        source: this.sourceTarget.value,
        brought_by_id: this.sourceTarget.value === "team_member" ? this.broughtByTarget.value : null,
        first_contact_on: this.firstContactOnTarget.value
      }
      const res = await fetch(`${this.peopleUrlValue}.json`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ person })
      })
      if (!res.ok) {
        const data = await res.json().catch(() => ({}))
        this.error((data.errors || [this.createFailedValue]).join(", "))
        return
      }
      const created = await res.json()
      this.selectTarget.add(new Option(created.name, created.id, true, true))
      this.close()
    } catch {
      this.error(this.networkErrorValue)
    } finally {
      this.submitTarget.disabled = false
    }
  }

  error(message) {
    this.errorTarget.textContent = message
    this.show(this.errorTarget)
  }

  show(el) { el.classList.remove("hidden") }
  hide(el) { el.classList.add("hidden") }
}
