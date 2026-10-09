module ClientPortalHelper
  def client_portal_preview?
    ClientPortal::SessionCookie.read(cookies)&.fetch(:preview, false)
  end

  def client_portal_preview_email
    ClientPortal::SessionCookie.read(cookies)&.fetch(:email)
  end

  # Wraps portal pages in the layout template chosen for the portal in workspace settings, if any.
  def client_portal_page_body(workspace, &block)
    content_html = capture(&block)
    template = workspace&.client_portal_layout_template
    return content_html if template.blank?

    PublicLayoutTemplates::Renderer.render(
      template: template,
      content_html: content_html,
      workspace: workspace,
      view_context: self
    )
  rescue Liquid::Error
    content_html
  end
end
