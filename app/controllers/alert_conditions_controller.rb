class AlertConditionsController < ApplicationController
  include RequiresFeature
  requires_feature :alerts
  before_action :set_alert_rule, only: %i[index new create]
  before_action :set_alert_condition, only: %i[edit update destroy]

  def index
    @alert_conditions = policy_scope(@alert_rule.alert_conditions).ordered
    authorize AlertCondition
  end

  def new
    @alert_condition = @alert_rule.alert_conditions.new(workspace: current_workspace)
    authorize @alert_condition
  end

  def create
    @alert_condition = @alert_rule.alert_conditions.new(alert_condition_params.merge(workspace: current_workspace))
    authorize @alert_condition

    if @alert_condition.save
      redirect_to alert_rule_alert_conditions_path(@alert_rule), notice: "Condición creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @alert_condition
  end

  def update
    authorize @alert_condition
    if @alert_condition.update(alert_condition_params)
      redirect_to alert_rule_alert_conditions_path(@alert_condition.alert_rule), notice: "Condición actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @alert_condition
    alert_rule = @alert_condition.alert_rule
    @alert_condition.destroy
    redirect_to alert_rule_alert_conditions_path(alert_rule), notice: "Condición eliminada.", status: :see_other
  end

  private

  def set_alert_rule
    @alert_rule = policy_scope(current_workspace.alert_rules).find(params[:alert_rule_id])
  end

  def set_alert_condition
    @alert_condition = policy_scope(current_workspace.alert_conditions).find(params[:id])
  end

  def alert_condition_params
    params.require(:alert_condition).permit(:field, :operator, :compare_value, :active, :position)
  end
end
