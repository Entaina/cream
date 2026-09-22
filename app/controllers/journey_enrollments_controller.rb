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
      t("flashes.journey_enrollments.moved", name: enrollment.person.display_name)
    when :not_in_progress
      t("flashes.journey_enrollments.not_in_progress")
    when :invalid_step
      t("flashes.journey_enrollments.invalid_step")
    else
      t("flashes.journey_enrollments.move_failed")
    end
  end
end
