class JourneyRunnerJob < ApplicationJob
  queue_as :default

  def perform
    Marketing::JourneyRunner.run!
  end
end
