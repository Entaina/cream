class JourneyEnrollmentsController < ApplicationController
  include RequiresFeature

  requires_feature :journeys

  def update
    journey = policy_scope(current_workspace.journeys).find(params[:journey_id])
    authorize journey, :update?
    enrollment = journey.enrollments.find(params[:id])
    step = journey.steps.find_by(id: params[:step_id])

    outcome = Marketing::JourneyStepMover.move!(enrollment: enrollment, step: step, actor: current_user)
    notice = move_notice_for(outcome, enrollment)

    if outcome == :moved
      redirect_to journey, notice: notice
    else
      redirect_to journey, alert: notice
    end
  end

  private

  def move_notice_for(outcome, enrollment)
    case outcome
    when :moved
      "#{enrollment.person.display_name} se ha movido al paso seleccionado."
    when :not_in_progress
      "Solo se puede cambiar el paso de inscripciones activas o en espera."
    when :invalid_step
      "El paso no pertenece a este recorrido."
    else
      "No se pudo cambiar el paso."
    end
  end
end
