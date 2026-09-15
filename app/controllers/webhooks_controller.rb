class WebhooksController < ApplicationController
  include RequiresFeature

  requires_feature :webhooks
  requires_workspace_feature :webhooks
  before_action :set_webhook, only: %i[edit update destroy]

  def index
    @webhooks = policy_scope(current_workspace.webhooks).order(:created_at)
    authorize Webhook
  end

  def new
    @webhook = current_workspace.webhooks.new(user: current_user, events: [Webhook::EVENTS.first])
    authorize @webhook
  end

  def create
    @webhook = current_workspace.webhooks.new(webhook_params.merge(user: current_user))
    authorize @webhook

    if @webhook.save
      redirect_to webhooks_path, notice: "Webhook created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @webhook
  end

  def update
    authorize @webhook
    if @webhook.update(webhook_params)
      redirect_to webhooks_path, notice: "Webhook updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @webhook
    @webhook.destroy
    redirect_to webhooks_path, notice: "Webhook deleted.", status: :see_other
  end

  private

  def set_webhook
    @webhook = policy_scope(current_workspace.webhooks).find(params[:id])
  end

  def webhook_params
    params.require(:webhook).permit(:url, :secret, :active, events: [])
  end
end
