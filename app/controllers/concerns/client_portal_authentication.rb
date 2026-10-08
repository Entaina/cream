module ClientPortalAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :client_portal_session, :client_portal_email
  end

  private

  def client_portal_session
    @client_portal_session ||= ClientPortal::SessionCookie.read(cookies)
  end

  # The cookie is shared by every workspace portal on this host, so it only counts for the workspace it was issued for.
  # Access is re-checked on every request: losing it (e.g. removed from the deals) ends the session.
  def require_client_portal_session!
    if client_portal_session && client_portal_workspace &&
        client_portal_session[:workspace_id] == client_portal_workspace.id
      return if ClientPortal::Access.allowed?(workspace: client_portal_workspace, email: client_portal_email)

      ClientPortal::SessionCookie.clear(cookies)
      return redirect_to client_portal_root_path(workspace_slug: params[:workspace_slug]), alert: t("client_portal.sessions.no_access")
    end

    redirect_to client_portal_root_path(workspace_slug: params[:workspace_slug])
  end

  def client_portal_workspace
    return @client_portal_workspace if defined?(@client_portal_workspace)

    slug = params[:workspace_slug]
    @client_portal_workspace = Workspace.find_by(slug: slug) if slug.present?
  end

  def client_portal_email
    client_portal_session&.fetch(:email)
  end

  def client_portal_people
    return Person.none unless client_portal_workspace && client_portal_email

    client_portal_workspace.people.with_email(client_portal_email)
  end

  def client_portal_person_for_deal(deal)
    client_portal_people.where(id: deal.deal_contacts.with_portal_access.select(:person_id)).first
  end
end
