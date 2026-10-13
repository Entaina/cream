import { Controller } from "@hotwired/stimulus"

// Deal contacts: multi-select chips, workspace search, browse contacts by company.
export default class extends Controller {
  static targets = [
    "companySelect", "partnerSelect", "chips", "searchInput", "menu", "hiddenFields",
    "dialog", "firstName", "lastName", "email", "phone", "source", "broughtByRow", "broughtBy",
    "firstContactOn", "notice", "error", "submit", "outsiderWarning", "chipField", "companyShortcuts"
  ]
  static values = {
    peopleUrl: String,
    companiesUrl: String,
    selected: Array,
    pickCompanyError: String,
    selectTeamMemberError: String,
    networkError: String,
    createFailed: String,
    today: String,
    noResults: String,
    groupClient: String,
    groupPartner: String,
    groupOther: String,
    groupCompanies: String,
    viewContactsLabel: String,
    addAllLabel: String,
    noContactsInCompany: String,
    backLabel: String,
    outsiderNoticeOne: String,
    outsiderNoticeMany: String,
    removeLabel: String,
    clientCompanyName: String,
    partnerCompanyName: String
  }

  connect() {
    this.selectedPeople = (this.hasSelectedValue ? [ ...this.selectedValue ] : [])
    this.menuEntries = []
    this.browseCompany = null
    this.browseReturnTo = null
    this.activeIndex = -1
    this.menuEl = this.menuTarget
    this.menuPortaled = false
    this.menuAnchor = document.createComment("deal-contacts-menu")
    this.onMenuMouseDown = (event) => event.preventDefault()
    this.onMenuClick = (event) => this.handleMenuClick(event)
    this.boundRepositionMenu = this.repositionMenu.bind(this)
    this.boundOnScroll = this.onScroll.bind(this)
    this.menuEl.addEventListener("mousedown", this.onMenuMouseDown)
    this.menuEl.addEventListener("click", this.onMenuClick)
    this.renderChips()
    this.syncHiddenFields()
    this.updateOutsiderNotice()
    this.renderCompanyShortcuts()
    this.toggleBroughtBy()
  }

  disconnect() {
    this.menuEl.removeEventListener("mousedown", this.onMenuMouseDown)
    this.menuEl.removeEventListener("click", this.onMenuClick)
    clearTimeout(this.debounce)
    this.removeMenuListeners()
    if (this.menuPortaled) {
      this.menuEl.remove()
      this.menuAnchor.remove()
    }
  }

  companyChanged() {
    this.updateChipStyles()
    this.updateOutsiderNotice()
    this.renderCompanyShortcuts()
    if (this.browseCompany) this.hideMenu()
  }

  focusSearch(event) {
    if (event.target === this.searchInputTarget) return
    this.searchInputTarget.focus()
  }

  async onSearchFocus() {
    if (this.browseCompany) return
    if (this.searchInputTarget.value.trim().length === 0) {
      await this.loadOrgSuggestions()
    }
  }

  query() {
    this.browseCompany = null
    this.browseReturnTo = null

    const q = this.searchInputTarget.value.trim()
    if (q.length === 0) {
      this.loadOrgSuggestions()
      return
    }

    clearTimeout(this.debounce)
    this.debounce = setTimeout(async () => {
      try {
        const [ people, companies ] = await Promise.all([
          this.fetchPeopleSearch(q),
          this.fetchCompaniesSearch(q)
        ])
        const filteredPeople = people.filter((person) => !this.hasPerson(person.id))
        const pinned = this.pinnedCompanies(q)
        const seenIds = new Set(pinned.map((c) => c.id))
        const mergedCompanies = [
          ...pinned,
          ...companies.filter((c) => !seenIds.has(c.id))
        ]
        this.renderSearchMenu(filteredPeople, mergedCompanies)
      } catch { /* ignore */ }
    }, 200)
  }

  async fetchPeopleSearch(q) {
    const res = await fetch(`${this.peopleUrlValue}.json?q=${encodeURIComponent(q)}`, {
      headers: { Accept: "application/json" }
    })
    if (!res.ok) return []
    return await res.json()
  }

  async fetchCompaniesSearch(q) {
    const res = await fetch(`${this.companiesUrlValue}?q=${encodeURIComponent(q)}`, {
      headers: { Accept: "application/json" }
    })
    if (!res.ok) return []
    return await res.json()
  }

  pinnedCompanies(q) {
    const needle = this.normalize(q)
    if (!needle) return []

    const pinned = []
    const companyId = this.companySelectTarget.value
    const partnerId = this.hasPartnerSelectTarget ? this.partnerSelectTarget.value : null
    const clientName = this.companyDisplayName()
    const partnerName = this.partnerDisplayName()

    if (companyId && clientName && this.normalize(clientName).includes(needle)) {
      pinned.push({ id: Number(companyId), name: clientName, hint: null })
    }
    if (partnerId && partnerName && partnerId !== companyId && this.normalize(partnerName).includes(needle)) {
      pinned.push({ id: Number(partnerId), name: partnerName, hint: null })
    }
    return pinned
  }

  async loadOrgSuggestions() {
    if (this.browseCompany) return

    const companyId = this.companySelectTarget.value
    const partnerId = this.hasPartnerSelectTarget ? this.partnerSelectTarget.value : null
    const companyIds = [ companyId, partnerId ].filter(Boolean)
    if (companyIds.length === 0) {
      this.hideMenu()
      return
    }

    try {
      const peopleArrays = await Promise.all(companyIds.map((id) => this.fetchPeopleForCompany(id)))
      const seen = new Set()
      const people = []
      for (const list of peopleArrays) {
        for (const person of list) {
          if (!seen.has(person.id) && !this.hasPerson(person.id)) {
            seen.add(person.id)
            people.push(person)
          }
        }
      }
      people.sort((a, b) => a.name.localeCompare(b.name))
      this.renderSearchMenu(people, [])
    } catch { /* ignore */ }
  }

  async fetchPeopleForCompany(id) {
    const res = await fetch(`${this.peopleUrlValue}.json?company_id=${id}`, { headers: { Accept: "application/json" } })
    if (!res.ok) return []
    return await res.json()
  }

  renderSearchMenu(people, companies) {
    const companyId = this.companySelectTarget.value
    const partnerId = this.hasPartnerSelectTarget ? this.partnerSelectTarget.value : null
    const client = []
    const partner = []
    const other = []

    people.forEach((person) => {
      const cid = person.company_id == null ? null : String(person.company_id)
      if (companyId && cid === String(companyId)) client.push(person)
      else if (partnerId && cid === String(partnerId)) partner.push(person)
      else other.push(person)
    })

    this.menuEntries = []
    let index = 0
    const items = []

    const pushPersonGroup = (label, records) => {
      if (records.length === 0) return
      items.push(this.groupHeader(label))
      records.forEach((record) => {
        items.push(this.personMenuItem(record, index))
        this.menuEntries.push({ type: "person", record })
        index += 1
      })
    }

    pushPersonGroup(this.groupClientValue, client)
    pushPersonGroup(this.groupPartnerValue, partner)
    pushPersonGroup(this.groupOtherValue, other)

    if (companies.length > 0) {
      items.push(this.groupHeader(this.groupCompaniesValue))
      companies.forEach((company) => {
        items.push(this.companyMenuItem(company, index))
        this.menuEntries.push({ type: "company", record: company })
        index += 1
      })
    }

    if (items.length === 0) {
      this.menuEl.innerHTML = `<li class="px-3 py-1.5 text-sm text-ink-faint">${this.escape(this.noResultsValue)}</li>`
      this.menuEntries = []
      this.openMenu()
      this.activeIndex = -1
      return
    }

    this.activeIndex = -1
    this.menuEl.innerHTML = items.join("")
    this.openMenu()
  }

  async openCompanyBrowse(companyId, companyName, returnTo) {
    this.browseCompany = { id: Number(companyId), name: companyName }
    this.browseReturnTo = returnTo
    await this.refreshCompanyBrowseMenu()
  }

  async refreshCompanyBrowseMenu() {
    if (!this.browseCompany) return

    const all = await this.fetchPeopleForCompany(this.browseCompany.id)
    const available = all.filter((person) => !this.hasPerson(person.id))
    this.renderCompanyBrowseMenu(available)
  }

  renderCompanyBrowseMenu(people) {
    this.menuEntries = []
    const items = []

    const addAllBtn = people.length > 0
      ? `<button type="button" data-menu-action="add-all-browse"
                class="ml-auto shrink-0 text-xs font-medium text-accent hover:underline">
           ${this.escape(this.addAllLabelValue)}
         </button>`
      : ""

    items.push(`<li class="sticky top-0 z-10 flex items-center gap-2 border-b border-line bg-canvas px-3 py-2">
      <button type="button" data-menu-action="browse-back" aria-label="${this.escape(this.backLabelValue)}"
              class="rounded-md p-1 text-ink-faint hover:bg-canvas-sunken hover:text-ink">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="size-4"><path fill-rule="evenodd" d="M9.78 4.22a.75.75 0 0 1 0 1.06L7.06 8l2.72 2.72a.75.75 0 1 1-1.06 1.06L5.47 8.53a.75.75 0 0 1 0-1.06l3.25-3.25a.75.75 0 0 1 1.06 0Z" clip-rule="evenodd"/></svg>
      </button>
      <span class="min-w-0 truncate text-sm font-semibold">${this.escape(this.browseCompany.name)}</span>
      ${addAllBtn}
    </li>`)

    if (people.length === 0) {
      items.push(`<li class="px-3 py-2 text-sm text-ink-faint">${this.escape(this.noContactsInCompanyValue)}</li>`)
    } else {
      let index = 0
      people.forEach((record) => {
        items.push(this.personMenuItem(record, index))
        this.menuEntries.push({ type: "browse-person", record })
        index += 1
      })
    }

    this.activeIndex = -1
    this.menuEl.innerHTML = items.join("")
    this.openMenu()
  }

  groupHeader(label) {
    return `<li class="px-3 py-1 text-xs font-semibold uppercase tracking-wide text-ink-faint bg-canvas-sunken/80">${this.escape(label)}</li>`
  }

  personMenuItem(record, index) {
    const hint = record.hint ? `<span class="text-ink-faint"> · ${this.escape(record.hint)}</span>` : ""
    return `<li role="option" data-menu-index="${index}"
                class="cursor-pointer px-3 py-1.5 text-sm hover:bg-canvas-sunken">
              <span class="font-medium">${this.escape(record.name)}</span>${hint}
            </li>`
  }

  companyMenuItem(company, index) {
    const hint = company.hint ? `<span class="text-ink-faint"> · ${this.escape(company.hint)}</span>` : ""
    const action = `<span class="text-ink-faint"> · ${this.escape(this.viewContactsLabelValue)}</span>`
    return `<li role="option" data-menu-index="${index}"
                class="cursor-pointer px-3 py-1.5 text-sm hover:bg-canvas-sunken">
              <span class="font-medium">${this.escape(company.name)}</span>${hint}${action}
            </li>`
  }

  handleMenuClick(event) {
    const actionEl = event.target.closest("[data-menu-action]")
    if (actionEl) {
      event.preventDefault()
      const action = actionEl.dataset.menuAction
      if (action === "browse-back") {
        this.companyBrowseBack()
        return
      }
      if (action === "add-all-browse") {
        this.addAllBrowsePeople()
        return
      }
    }

    const option = event.target.closest('[role="option"]')
    if (!option || option.dataset.menuIndex === undefined) return
    event.preventDefault()

    const entry = this.menuEntries[Number(option.dataset.menuIndex)]
    if (!entry) return

    if (entry.type === "person") {
      this.addPerson(entry.record)
      this.searchInputTarget.value = ""
      this.browseCompany = null
      this.hideMenu()
      return
    }

    if (entry.type === "company") {
      const q = this.searchInputTarget.value.trim()
      this.openCompanyBrowse(entry.record.id, entry.record.name, { type: "search", q })
      return
    }

    if (entry.type === "browse-person") {
      this.addPerson(entry.record)
      this.refreshCompanyBrowseMenu()
    }
  }

  companyBrowseBack() {
    const returnTo = this.browseReturnTo
    this.browseCompany = null
    this.browseReturnTo = null

    if (!returnTo || returnTo.type === "shortcut") {
      this.hideMenu()
      return
    }

    if (returnTo.type === "search") {
      const q = returnTo.q || ""
      this.searchInputTarget.value = q
      if (q.length === 0) {
        this.loadOrgSuggestions()
      } else {
        this.query()
      }
    }
  }

  addAllBrowsePeople() {
    for (const entry of this.menuEntries) {
      if (entry.type === "browse-person") this.addPerson(entry.record)
    }
    this.browseCompany = null
    this.browseReturnTo = null
    this.searchInputTarget.value = ""
    this.hideMenu()
  }

  openCompanyShortcut(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.companyId
    const name = event.currentTarget.dataset.companyName
    if (!id || !name) return
    this.searchInputTarget.focus()
    this.openCompanyBrowse(id, name, { type: "shortcut" })
  }

  renderCompanyShortcuts() {
    if (!this.hasCompanyShortcutsTarget) return

    const shortcuts = []
    const companyId = this.companySelectTarget.value
    const partnerId = this.hasPartnerSelectTarget ? this.partnerSelectTarget.value : null
    const clientName = this.companyDisplayName()
    const partnerName = this.partnerDisplayName()

    if (companyId && clientName) {
      shortcuts.push({ id: companyId, name: clientName })
    }
    if (partnerId && partnerName && partnerId !== companyId) {
      shortcuts.push({ id: partnerId, name: partnerName })
    }

    if (shortcuts.length === 0) {
      this.companyShortcutsTarget.innerHTML = ""
      this.companyShortcutsTarget.classList.add("hidden")
      return
    }

    this.companyShortcutsTarget.classList.remove("hidden")
    this.companyShortcutsTarget.innerHTML = shortcuts.map((shortcut) =>
      `<button type="button"
               class="inline-flex items-center gap-1 rounded-full border border-line bg-canvas-sunken px-2.5 py-1 text-xs font-medium text-ink hover:bg-canvas hover:border-line-strong"
               data-action="deal-contacts#openCompanyShortcut"
               data-company-id="${shortcut.id}"
               data-company-name="${this.attrEscape(shortcut.name)}">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="size-3.5 text-ink-faint"><path d="M8 8a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM3.156 13.25a5.25 5.25 0 0 1 9.688 0 .75.75 0 0 1-.351.961 7 7 0 0 1-8.986 0 .75.75 0 0 1-.351-.961ZM8 1a4 4 0 0 0-4 4v.5a.75.75 0 0 0 1.5 0V5a2.5 2.5 0 0 1 5 0v.5a.75.75 0 0 0 1.5 0V5a4 4 0 0 0-4-4Z"/></svg>
        <span class="truncate max-w-[14rem]">${this.escape(shortcut.name)}</span>
       </button>`
    ).join("")
  }

  addPerson(record) {
    if (this.hasPerson(record.id)) return
    this.selectedPeople.push(record)
    this.renderChips()
    this.syncHiddenFields()
    this.updateOutsiderNotice()
  }

  remove(event) {
    event.preventDefault()
    const id = Number(event.currentTarget.dataset.personId)
    this.selectedPeople = this.selectedPeople.filter((person) => person.id !== id)
    this.renderChips()
    this.syncHiddenFields()
    this.updateOutsiderNotice()
  }

  hasPerson(id) {
    return this.selectedPeople.some((person) => person.id === id)
  }

  renderChips() {
    this.chipsTarget.innerHTML = this.selectedPeople.map((person) => this.chipHtml(person)).join("")
  }

  chipHtml(person) {
    const outsider = this.isOutsider(person)
    const ring = outsider
      ? "ring-1 ring-amber-400/80 border-amber-300/80 dark:border-amber-700"
      : "border-line"
    const hint = person.hint ? `<span class="text-ink-faint truncate max-w-[12rem]">${this.escape(person.hint)}</span>` : ""
    return `<span data-person-id="${person.id}" class="inline-flex max-w-full items-center gap-1 rounded-full border ${ring} bg-canvas-sunken pl-2.5 pr-1 py-0.5 text-sm">
      <span class="font-medium truncate">${this.escape(person.name)}</span>
      ${hint}
      <button type="button" class="rounded-full p-0.5 text-ink-faint hover:bg-canvas hover:text-ink"
              data-person-id="${person.id}" data-action="deal-contacts#remove"
              aria-label="${this.escape(this.removeLabelValue)}">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="size-3.5"><path d="M4.28 4.22a.75.75 0 0 0-1.06 1.06L6.94 8l-3.72 3.72a.75.75 0 1 0 1.06 1.06L8 9.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L9.06 8l3.72-3.72a.75.75 0 0 0-1.06-1.06L8 6.94 4.28 3.22Z"/></svg>
      </button>
    </span>`
  }

  updateChipStyles() {
    this.renderChips()
  }

  syncHiddenFields() {
    this.hiddenFieldsTarget.innerHTML = this.selectedPeople.map((person) =>
      `<input type="hidden" name="deal[contact_ids][]" value="${person.id}">`
    ).join("")
  }

  companyDisplayName() {
    return this.pickerInputFor(this.companySelectTarget)?.value || this.clientCompanyNameValue || ""
  }

  partnerDisplayName() {
    if (!this.hasPartnerSelectTarget) return this.partnerCompanyNameValue || ""
    return this.pickerInputFor(this.partnerSelectTarget)?.value || this.partnerCompanyNameValue || ""
  }

  pickerInputFor(hidden) {
    return hidden?.closest('[data-controller~="record-picker"]')?.querySelector('[data-record-picker-target="input"]')
  }

  allowedCompanyIds() {
    return [
      this.companySelectTarget.value,
      this.hasPartnerSelectTarget ? this.partnerSelectTarget.value : null
    ].filter(Boolean).map(String)
  }

  isOutsider(person) {
    const allowed = this.allowedCompanyIds()
    if (allowed.length === 0) return false
    const cid = person.company_id == null ? null : String(person.company_id)
    if (cid === null) return true
    return !allowed.includes(cid)
  }

  updateOutsiderNotice() {
    if (!this.hasOutsiderWarningTarget) return
    const outsiders = this.selectedPeople.filter((person) => this.isOutsider(person))
    if (outsiders.length === 0) {
      this.outsiderWarningTarget.classList.add("hidden")
      this.outsiderWarningTarget.textContent = ""
      return
    }

    const names = outsiders.map((person) => person.name).join(", ")
    const companies = [ this.companyDisplayName(), this.partnerDisplayName() ].filter(Boolean).join(" / ")
    const template = outsiders.length === 1 ? this.outsiderNoticeOneValue : this.outsiderNoticeManyValue
    this.outsiderWarningTarget.textContent = template
      .replace("%{names}", names)
      .replace("%{companies}", companies)
    this.outsiderWarningTarget.classList.remove("hidden")
  }

  searchKeydown(event) {
    if (event.key === "Backspace" && this.searchInputTarget.value.length === 0 && this.selectedPeople.length > 0) {
      this.selectedPeople.pop()
      this.renderChips()
      this.syncHiddenFields()
      this.updateOutsiderNotice()
      event.preventDefault()
      return
    }

    const options = this.menuOptions()
    if (event.key === "Escape") {
      if (this.browseCompany) {
        this.companyBrowseBack()
      } else {
        this.hideMenu()
      }
      event.preventDefault()
      return
    }

    if (this.menuEl.classList.contains("hidden") || options.length === 0) return

    if (event.key === "ArrowDown") {
      this.activeIndex = Math.min(this.activeIndex + 1, options.length - 1)
      this.highlightOption(options)
      event.preventDefault()
      return
    }

    if (event.key === "ArrowUp") {
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlightOption(options)
      event.preventDefault()
      return
    }

    if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      options[this.activeIndex].click()
    }
  }

  menuOptions() {
    return Array.from(this.menuEl.querySelectorAll('[role="option"]'))
  }

  highlightOption(options) {
    options.forEach((option, index) => {
      option.classList.toggle("bg-canvas-sunken", index === this.activeIndex)
    })
    options[this.activeIndex]?.scrollIntoView({ block: "nearest" })
  }

  searchBlur() {
    setTimeout(() => this.hideMenu(), 150)
  }

  openMenu() {
    this.portalMenu()
    this.repositionMenu()
    this.menuEl.classList.remove("hidden")
  }

  portalMenu() {
    if (this.menuPortaled) return

    this.menuEl.parentNode.insertBefore(this.menuAnchor, this.menuEl)
    document.body.appendChild(this.menuEl)
    this.menuPortaled = true
    this.menuEl.classList.add("rounded-md", "border", "border-line", "bg-canvas", "shadow-lg", "max-h-56", "overflow-y-auto")
    window.addEventListener("scroll", this.boundOnScroll, true)
    window.addEventListener("resize", this.boundRepositionMenu)
  }

  unportalMenu() {
    if (!this.menuPortaled) return

    this.removeMenuListeners()
    this.menuAnchor.parentNode?.insertBefore(this.menuEl, this.menuAnchor)
    this.menuAnchor.remove()
    this.resetMenuStyles()
    this.menuPortaled = false
  }

  removeMenuListeners() {
    window.removeEventListener("scroll", this.boundOnScroll, true)
    window.removeEventListener("resize", this.boundRepositionMenu)
  }

  repositionMenu() {
    const anchor = this.chipFieldTarget
    const rect = anchor.getBoundingClientRect()
    this.menuEl.style.position = "fixed"
    this.menuEl.style.top = `${rect.bottom + 4}px`
    this.menuEl.style.left = `${rect.left}px`
    this.menuEl.style.width = `${rect.width}px`
    this.menuEl.style.zIndex = "9999"
  }

  onScroll() {
    if (this.menuEl.classList.contains("hidden")) return
    this.repositionMenu()
  }

  resetMenuStyles() {
    this.menuEl.style.position = ""
    this.menuEl.style.top = ""
    this.menuEl.style.left = ""
    this.menuEl.style.width = ""
    this.menuEl.style.zIndex = ""
  }

  hideMenu() {
    this.menuEl.classList.add("hidden")
    this.activeIndex = -1
    this.browseCompany = null
    this.browseReturnTo = null
    this.unportalMenu()
  }

  open(event) {
    event.preventDefault()
    if (!this.companySelectTarget.value) {
      this.noticeTarget.textContent = this.pickCompanyErrorValue
      this.show(this.noticeTarget)
      return
    }
    this.hide(this.noticeTarget)
    this.hide(this.errorTarget)
    this.firstNameTarget.value = ""
    this.lastNameTarget.value = ""
    this.emailTarget.value = ""
    this.phoneTarget.value = ""
    this.sourceTarget.value = ""
    this.broughtByTarget.value = ""
    this.toggleBroughtBy()
    this.firstContactOnTarget.value = this.todayValue
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
      this.addPerson({
        id: created.id,
        name: created.name,
        company_id: Number(this.companySelectTarget.value),
        hint: created.hint || null
      })
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

  normalize(text) {
    return (text ?? "").normalize("NFD").replace(/\p{M}/gu, "").toLowerCase()
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text ?? ""
    return div.innerHTML
  }

  attrEscape(text) {
    return String(text ?? "")
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
  }
}
