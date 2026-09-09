class SubscriptionTypesController < ApplicationController
  include RequiresFeature
  requires_feature :marketing_consent
  before_action :set_subscription_type, only: %i[edit update destroy]

  def index
    @subscription_types = policy_scope(current_workspace.subscription_types).ordered
    authorize SubscriptionType
    SubscriptionType.ensure_defaults!(current_workspace) if @subscription_types.empty?
    @subscription_types = policy_scope(current_workspace.subscription_types).ordered
  end

  def new
    @subscription_type = current_workspace.subscription_types.new
    authorize @subscription_type
  end

  def create
    @subscription_type = current_workspace.subscription_types.new(subscription_type_params)
    authorize @subscription_type
    if @subscription_type.save
      redirect_to subscription_types_path, notice: "Tipo de suscripción creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @subscription_type
  end

  def update
    authorize @subscription_type
    if @subscription_type.update(subscription_type_params)
      redirect_to subscription_types_path, notice: "Tipo de suscripción actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @subscription_type
    @subscription_type.destroy
    redirect_to subscription_types_path, notice: "Tipo de suscripción eliminado.", status: :see_other
  end

  private

  def set_subscription_type
    @subscription_type = policy_scope(current_workspace.subscription_types).find(params[:id])
  end

  def subscription_type_params
    params.require(:subscription_type).permit(
      :name, :slug, :description, :position, :active, :consent_field_key, :default_consent_label
    )
  end
end
