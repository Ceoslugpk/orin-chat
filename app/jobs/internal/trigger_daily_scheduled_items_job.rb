class Internal::TriggerDailyScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Schedule daily deferred jobs here.
    Internal::ExpireDataOperationFilesJob.perform_later
  end
end

Internal::TriggerDailyScheduledItemsJob.prepend_mod_with('Internal::TriggerDailyScheduledItemsJob')
