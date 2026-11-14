require 'rails_helper'

RSpec.describe Internal::TriggerDailyScheduledItemsJob do
  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  it 'enqueues the data operation file cleanup' do
    expect { described_class.perform_now }.to have_enqueued_job(Internal::ExpireDataOperationFilesJob)
  end
end
