class MailjetConnectionsController < ApplicationController
  include RequiresFeature

  requires_feature :marketing_campaigns

  def create
    @mailjet_connection = current_workspace.build_mailjet_connection(connection_params.merge(user: current_user))
    authorize @mailjet_connection
    save_connection(t("flashes.mailjet.connected"))
  end

  def update
    @mailjet_connection = find_connection
    authorize @mailjet_connection

    attrs = connection_params
    attrs = attrs.except(:api_key) if attrs[:api_key].blank?
    attrs = attrs.except(:secret_key) if attrs[:secret_key].blank?
    @mailjet_connection.assign_attributes(attrs)
    save_connection(t("flashes.mailjet.updated"))
  end

  def destroy
    @mailjet_connection = find_connection
    authorize @mailjet_connection
    remove_mailjet_webhooks!
    @mailjet_connection.destroy
    redirect_to settings_workspace_path, notice: t("flashes.mailjet.disconnected"), status: :see_other
  end

  private

  def connection_params
    params.require(:mailjet_connection).permit(
      :api_key, :secret_key, :from_email, :from_name, :transactional_enabled, :sender_domain_validated
    )
  end

  def find_connection
    current_workspace.mailjet_connection || raise(ActiveRecord::RecordNotFound)
  end

  def save_connection(notice)
    if @mailjet_connection.save
      webhook_notice = sync_mailjet_webhooks!
      redirect_to settings_workspace_path, notice: [notice, webhook_notice].compact.join(" ")
    else
      render "settings/workspace/show", status: :unprocessable_entity
    end
  end

  def sync_mailjet_webhooks!
    Marketing::Esp::MailjetWebhookRegistrar.sync!(@mailjet_connection)
    t("flashes.mailjet.webhook_registered")
  rescue => e
    Rails.logger.warn("[MailjetWebhookRegistrar] sync failed: #{e.message}")
    t("flashes.mailjet.webhook_failed")
  end

  def remove_mailjet_webhooks!
    Marketing::Esp::MailjetWebhookRegistrar.remove!(@mailjet_connection)
  rescue => e
    Rails.logger.warn("[MailjetWebhookRegistrar] remove failed: #{e.message}")
  end
end
