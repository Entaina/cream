class ClientPortalMailer < ApplicationMailer
  def login_link(workspace:, email:, token:)
    @workspace = workspace
    @url = client_portal_access_consume_url(workspace_slug: workspace.slug, token: token)

    with_mailer_locale do
      mail(
        to: email,
        subject: I18n.t("client_portal.mailer.login_link.subject", workspace: workspace.name),
        **portal_from_options
      )
    end
  end

  def deal_portal_invite_link(grant:, raw_token:)
    invite_link = grant.deal_portal_invite_link
    @workspace = invite_link.workspace
    @deal = invite_link.deal
    @url = client_portal_deal_portal_invite_access_url(
      workspace_slug: @workspace.slug,
      token: invite_link.token,
      grant_token: raw_token
    )

    with_mailer_locale do
      mail(
        to: grant.email,
        subject: I18n.t("client_portal.mailer.deal_portal_invite.subject", deal: @deal.name),
        **portal_from_options
      )
    end
  end

  def offer_access_link(grant:, raw_token:)
    share_link = grant.offer_share_link
    @workspace = share_link.workspace
    @offer = share_link.offer
    @url = public_offer_share_access_url(token: share_link.token, grant_token: raw_token)

    with_mailer_locale do
      mail(
        to: grant.email,
        subject: I18n.t("client_portal.mailer.offer_access_link.subject", offer: @offer.name),
        **portal_from_options
      )
    end
  end

  private

  def mailjet_workspace
    @workspace
  end

  def portal_from_options
    from = @workspace&.portal_mail_from
    from ? { from: from } : {}
  end
end
