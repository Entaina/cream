module ClientPortal
  class OfferViewRecorder
    def self.record!(offer:, person:, version:, share_link: nil)
      OfferView.create!(
        workspace: offer.workspace,
        offer: offer,
        offer_version: version,
        person: person,
        viewed_at: Time.current,
        offer_share_link: share_link
      )

      metadata = {
        "offer" => offer.name,
        "offer_id" => offer.id,
        "version" => version.number,
        "contact" => person.display_name,
        "contact_id" => person.id
      }
      if share_link
        metadata["shared_by"] = share_link.person.display_name
        metadata["shared_by_id"] = share_link.person_id
      end

      offer.deal.track_activity("offer_viewed", user: nil, metadata: metadata)
    end
  end
end
