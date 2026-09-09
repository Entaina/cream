class BeehiivPushJob < ApplicationJob
  queue_as :default

  def perform(workspace_id, person_id, action, options = {})
    workspace = Workspace.find(workspace_id)
    connection = workspace.beehiiv_connection
    return unless connection&.connected?

    person = workspace.people.find_by(id: person_id)
    return unless person

    case action.to_s
    when "subscribe"
      Marketing::Beehiiv::PushService.subscribe!(
        connection: connection,
        person: person,
        reactivate: options["reactivate"] == true
      )
    when "unsubscribe"
      Marketing::Beehiiv::PushService.unsubscribe!(connection: connection, person: person)
    end
  end
end
