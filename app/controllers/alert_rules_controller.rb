class AlertRulesController < ApplicationController
  include RequiresFeature

  requires_feature :alerts
  before_action :set_alert_rule, only: %i[edit update destroy]

  def index
    @alert_rules = policy_scope(current_workspace.alert_rules).includes(:alert_conditions).order(:name)
    authorize AlertRule
  end

  def new
    @alert_rule = current_workspace.alert_rules.new(
      trigger_field: AlertRule::TRIGGER_FIELDS.first,
      recipient: AlertRule::RECIPIENTS.first,
      offset_days: 0
    )
    authorize @alert_rule
  end

  def create
    @alert_rule = current_workspace.alert_rules.new(alert_rule_params)
    authorize @alert_rule

    if @alert_rule.save
      redirect_to alert_rules_path, notice: "Alerta creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @alert_rule
  end

  def update
    authorize @alert_rule
    if @alert_rule.update(alert_rule_params)
      redirect_to alert_rules_path, notice: "Alerta actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @alert_rule
    @alert_rule.destroy
    redirect_to alert_rules_path, notice: "Alerta eliminada.", status: :see_other
  end

  private

  def set_alert_rule
    @alert_rule = policy_scope(current_workspace.alert_rules).includes(:alert_conditions).find(params[:id])
  end

  def alert_rule_params
    params.require(:alert_rule).permit(
      :name, :trigger_field, :offset_days, :recipient, :active,
      alert_conditions_attributes: %i[id field operator compare_value active _destroy]
    )
  end
end
