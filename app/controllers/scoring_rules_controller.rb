class ScoringRulesController < ApplicationController
  include RequiresFeature
  requires_feature :lead_scoring
  requires_workspace_feature :lead_scoring
  before_action :set_scoring_rule, only: %i[edit update destroy]

  def index
    @scoring_rules = policy_scope(current_workspace.scoring_rules).ordered
    authorize ScoringRule
  end

  def new
    @scoring_rule = current_workspace.scoring_rules.new(points: 5, active: true)
    authorize @scoring_rule
  end

  def create
    @scoring_rule = current_workspace.scoring_rules.new(scoring_rule_params)
    authorize @scoring_rule
    if @scoring_rule.save
      redirect_to scoring_rules_path, notice: "Regla de scoring creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @scoring_rule
  end

  def update
    authorize @scoring_rule
    if @scoring_rule.update(scoring_rule_params)
      redirect_to scoring_rules_path, notice: "Regla de scoring actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @scoring_rule
    @scoring_rule.destroy
    redirect_to scoring_rules_path, notice: "Regla de scoring eliminada.", status: :see_other
  end

  def recalculate
    authorize ScoringRule
    ScoringRecalculateJob.perform_later(current_workspace.id)
    redirect_to scoring_rules_path, notice: "Recálculo de puntuación encolado."
  end

  private

  def set_scoring_rule
    @scoring_rule = policy_scope(current_workspace.scoring_rules).find(params[:id])
  end

  def scoring_rule_params
    permitted = params.require(:scoring_rule).permit(:name, :event_type, :points, :decay_days, :active, conditions: [ :field, :operator, :compare_value ])
    conditions = Array(permitted[:conditions]).map(&:to_h).reject { |row| row["field"].blank? }
    permitted.merge(conditions: conditions)
  end
end
