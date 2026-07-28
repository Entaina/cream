class StageTriggerJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(trigger, deal, user)
    return unless CreamFeatures.enabled?(:stage_triggers) && trigger.active?

    run = trigger.runs.create!(workspace: trigger.workspace, deal: deal, user: user)
    StageTriggers::Runner.call(trigger: trigger, deal: deal, user: user, run: run)
  end
end
