class StripeConnectionsController < ApplicationController
  include RequiresFeature

  requires_feature :stripe_payments

  def show
    @connection = find_or_initialize_connection
    authorize @connection
  end

  def create
    @connection = current_workspace.stripe_connections.new(connection_params.merge(user: current_user))
    authorize @connection
    save_with_verified_key(@connection, t("flashes.stripe.connected"))
  end

  def update
    @connection = current_workspace.stripe_connections.first!
    authorize @connection

    attrs = connection_params
    # A blank key field on the form means "keep the stored key".
    attrs = attrs.except(:api_key) if attrs[:api_key].blank?
    @connection.assign_attributes(attrs)
    save_with_verified_key(@connection, t("flashes.stripe.updated"))
  end

  def sync
    @connection = current_workspace.stripe_connections.first!
    authorize @connection

    unless @connection.connected?
      redirect_to stripe_connection_path, alert: t("flashes.stripe.add_api_key_first") and return
    end

    StripeSyncJob.perform_later(@connection.id)
    redirect_to stripe_connection_path, notice: t("flashes.stripe.sync_started")
  end

  def destroy
    @connection = current_workspace.stripe_connections.first!
    authorize @connection
    @connection.destroy
    redirect_to stripe_connection_path, notice: t("flashes.stripe.disconnected"), status: :see_other
  end

  private

  def find_or_initialize_connection
    current_workspace.stripe_connections.first ||
      current_workspace.stripe_connections.new(user: current_user)
  end

  def connection_params
    params.require(:stripe_connection).permit(:api_key, :account_label, :sync_enabled)
  end

  def save_with_verified_key(connection, notice)
    if connection.api_key_changed? && connection.api_key.present? && connection.valid?
      StripeClient.new(api_key: connection.api_key).verify!
    end

    if connection.save
      # Kick off an import right away — waiting for the recurring scheduler
      # (production-only) made a freshly connected account look broken.
      if connection.connected?
        StripeSyncJob.perform_later(connection.id)
        notice = [notice, t("flashes.stripe.importing_payments")].join(" ")
      end
      redirect_to stripe_connection_path, notice: notice
    else
      render :show, status: :unprocessable_entity
    end
  rescue StripeClient::AuthenticationError
    connection.errors.add(:api_key, t("flashes.stripe.api_key_rejected"))
    render :show, status: :unprocessable_entity
  rescue StripeClient::Error => e
    connection.errors.add(:base, "#{t('flashes.stripe.verify_failed')}: #{e.message}")
    render :show, status: :unprocessable_entity
  end
end
