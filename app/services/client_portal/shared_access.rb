module ClientPortal
  class SharedAccess
    def self.ensure_contact!(deal:, email:, source:, offer_share_link: nil)
      workspace = deal.workspace
      normalized = OfferAccessGrant.normalize_email(email)
      person = Person.find_by_email(workspace, normalized)
      person ||= create_person!(workspace:, deal:, email: normalized, source: source)

      deal_contact = deal.deal_contacts.find_by(person: person)
      if deal_contact.nil?
        attrs = {person: person, source: source}
        attrs[:offer_share_link] = offer_share_link if offer_share_link
        deal.deal_contacts.create!(attrs)
      elsif deal_contact.via_offer_share? && source == "portal_invite"
        deal_contact.update!(source: source)
      end

      person
    end

    def self.create_person!(workspace:, deal:, email:, source:)
      local = email.split("@", 2).first.to_s
      local = "Contact" if local.blank?

      person = workspace.people.create!(
        company: deal.company,
        first_name: local,
        email: email,
        source: source
      )
      person.add_email!(email, primary: true) if person.email != email
      person
    end
    private_class_method :create_person!
  end
end
