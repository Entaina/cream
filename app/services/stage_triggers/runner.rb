module StageTriggers
  # Executes a single trigger run. Never re-raises: a broken trigger must not
  # retry in a loop against the LLM.
  class Runner
    def self.call(trigger:, deal:, user:, run:)
      run.start!
      ui = UiEmitter.new(user: user, deal: deal, run: run)
      if trigger.native?
        run.transcript << {"type" => "native_call", "function" => trigger.native_function}
        run.save!
        NativeRegistry.handler_for(trigger.native_function)
          .call(deal: deal, user: user, trigger: trigger, ui: ui, params: trigger.native_params)
      else
        LlmExecutor.new(trigger: trigger, deal: deal, user: user, ui: ui, run: run).call
      end
      run.succeed!
    rescue => e
      Rails.logger.error("StageTrigger #{trigger.id} failed on deal #{deal.id}: #{e.class} #{e.message}")
      run.fail!("#{e.class}: #{e.message}")
    end
  end
end
