class JourneysController < ApplicationController
  include RequiresFeature
  requires_feature :journeys
  before_action :set_journey, only: %i[show edit update destroy enroll toggle_active]

  def index
    @journeys = policy_scope(current_workspace.journeys).ordered
    authorize Journey
  end

  def show
    authorize @journey
    @enrollments = @journey.enrollments.includes(:person, :current_step).order(enrolled_at: :desc).limit(50)
    @stats = {
      total: @journey.enrollments.count,
      active: @journey.enrollments.where(state: "active").count,
      waiting: @journey.enrollments.where(state: "waiting").count,
      completed: @journey.enrollments.where(state: "completed").count
    }
  end

  def new
    @journey = current_workspace.journeys.new(entry_trigger: Journey::ENTRY_TRIGGERS.first, active: true)
    @journey.steps.build(position: 0, step_type: "send_email")
    authorize @journey
    load_form_collections
  end

  def create
    @journey = current_workspace.journeys.new(journey_params)
    authorize @journey
    if @journey.save
      redirect_to @journey, notice: "Recorrido creado."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @journey
    load_form_collections
  end

  def update
    authorize @journey
    if @journey.update(journey_params)
      redirect_to @journey, notice: "Recorrido actualizado."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @journey
    @journey.destroy
    redirect_to journeys_path, notice: "Recorrido eliminado.", status: :see_other
  end

  def enroll
    authorize @journey, :update?
    person = current_workspace.people.find(params[:person_id])
    outcome = Marketing::JourneyTrigger.enroll!(journey: @journey, person: person)
    notice = case outcome
    when :enrolled
      "#{person.display_name} inscrito en el recorrido."
    when :blocked
      "No se puede inscribir: hay una oportunidad abierta para este producto."
    when :max_reenrollments
      "Se alcanzó el límite de reinscripciones para este contacto."
    when :no_steps
      "El recorrido no tiene pasos activos."
    else
      "No se pudo inscribir al contacto."
    end

    if outcome == :enrolled
      redirect_to @journey, notice: notice
    else
      redirect_to @journey, alert: notice
    end
  end

  def toggle_active
    authorize @journey, :update?
    @journey.update!(active: !@journey.active?)
    redirect_to @journey, notice: @journey.active? ? "Recorrido activado." : "Recorrido pausado."
  end

  private

  def set_journey
    @journey = policy_scope(current_workspace.journeys).includes(:steps).find(params[:id])
  end

  def load_form_collections
    @lead_forms = current_workspace.lead_forms.order(:name)
    @segments = current_workspace.segments.where(record_type: "Person").ordered
    @booking_pages = current_workspace.booking_pages.order(:name)
    @email_templates = current_workspace.email_templates.ordered
    @lists = current_workspace.lists.where(record_type: "Person").order(:name)
    @users = current_workspace.users.order(:name)
    SubscriptionType.ensure_defaults!(current_workspace)
    @subscription_types = current_workspace.subscription_types.active.ordered
  end

  def journey_params
    params.require(:journey).permit(
      :name, :active, :entry_trigger, :max_reenrollments, :product_id, :stop_on_open_deal,
      entry_config: {},
      steps_attributes: [ :id, :position, :step_type, :active, :_destroy, config: {} ]
    )
  end
end
