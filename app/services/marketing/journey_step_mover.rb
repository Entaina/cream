module Marketing
  class JourneyStepMover
    def self.move!(enrollment:, step:, actor: nil)
      return :not_in_progress unless enrollment.in_progress?
      return :invalid_step if step.blank? || step.journey_id != enrollment.journey_id

      moves = Array(enrollment.metadata.to_h["manual_moves"])
      moves << {
        "from_step_id" => enrollment.current_step_id,
        "to_step_id" => step.id,
        "from_state" => enrollment.state,
        "actor_id" => actor&.id,
        "at" => Time.current.iso8601
      }

      enrollment.update!(
        current_step: step,
        state: "active",
        next_run_at: Time.current,
        metadata: enrollment.metadata.to_h.merge("manual_moves" => moves.last(20))
      )
      :moved
    end
  end
end
