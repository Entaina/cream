class BeehiivPushJob < ApplicationJob
  queue_as :default

  def perform(publication_id, person_id, action, options = {})
    publication = BeehiivPublication.find(publication_id)
    connection = publication.beehiiv_connection
    return unless connection.connected?

    person = publication.workspace.people.find_by(id: person_id)
    return unless person

    case action.to_s
    when "subscribe"
      Marketing::Beehiiv::PushService.subscribe!(
        publication: publication,
        person: person,
        reactivate: options["reactivate"] == true
      )
    when "unsubscribe"
      Marketing::Beehiiv::PushService.unsubscribe!(publication: publication, person: person)
    end
  end
end
