class SlackIntegrationsController < ApplicationController
  include RequiresFeature
  requires_feature :slack_integrations
  before_action :set_integration, only: %i[edit update destroy]

  def index
    @integrations = policy_scope(current_workspace.slack_integrations).order(:created_at)
    authorize SlackIntegration
  end

  def new
    @integration = current_workspace.slack_integrations.new(notify_events: [ SlackIntegration::NOTIFY_EVENTS.first ])
    authorize @integration
  end

  def create
    @integration = current_workspace.slack_integrations.new(integration_params)
    authorize @integration

    if @integration.save
      redirect_to slack_integrations_path, notice: "Slack integration created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @integration
  end

  def update
    authorize @integration
    if @integration.update(integration_params)
      redirect_to slack_integrations_path, notice: "Slack integration updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @integration
    @integration.destroy
    redirect_to slack_integrations_path, notice: "Slack integration removed.", status: :see_other
  end

  private

  def set_integration
    @integration = policy_scope(current_workspace.slack_integrations).find(params[:id])
  end

  def integration_params
    params.require(:slack_integration).permit(:webhook_url, :active, notify_events: [])
  end
end
