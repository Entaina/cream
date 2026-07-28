class AutomationsController < ApplicationController
  include RequiresFeature
  requires_feature :automations
  before_action :set_automation, only: %i[edit update destroy]

  def index
    @automations = policy_scope(current_workspace.automations).order(:name)
    authorize Automation
  end

  def new
    @automation = current_workspace.automations.new(
      trigger_event: Automation::TRIGGER_EVENTS.first,
      action_type: Automation::ACTION_TYPES.first
    )
    authorize @automation
  end

  def create
    @automation = current_workspace.automations.new(automation_params)
    @automation.trigger_conditions = build_conditions
    authorize @automation

    if @automation.save
      redirect_to automations_path, notice: "Automation created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @automation
  end

  def update
    authorize @automation
    if @automation.update(automation_params.merge(trigger_conditions: build_conditions))
      redirect_to automations_path, notice: "Automation updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @automation
    @automation.destroy
    redirect_to automations_path, notice: "Automation deleted.", status: :see_other
  end

  private

  def set_automation
    @automation = policy_scope(current_workspace.automations).find(params[:id])
  end

  def automation_params
    params.require(:automation).permit(:name, :trigger_event, :action_type, :active,
      action_params: %i[title due_on subject body])
  end

  # Zips the condition_keys/condition_values row arrays from the builder into the
  # trigger_conditions hash the engine matches against. Blank-keyed rows are
  # dropped so an empty row doesn't become a "" => "" condition.
  def build_conditions
    keys = Array(params.dig(:automation, :condition_keys))
    values = Array(params.dig(:automation, :condition_values))

    keys.zip(values).each_with_object({}) do |(key, value), conditions|
      key = key.to_s.strip
      conditions[key] = value.to_s if key.present?
    end
  end
end
