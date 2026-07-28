class AutomationJob < ApplicationJob
  queue_as :default

  def perform(event, record, metadata = {})
    AutomationEngine.run(event: event, record: record, metadata: metadata)
  end
end
