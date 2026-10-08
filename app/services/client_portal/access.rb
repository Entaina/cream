module ClientPortal
  # Who may hold a portal session: a contact of at least one deal with portal access (not only via a shared proposal).
  class Access
    def self.allowed?(workspace:, email:)
      return false if workspace.nil? || email.blank?

      DealContact.with_portal_access.where(person_id: workspace.people.with_email(email).select(:id)).exists?
    end
  end
end
