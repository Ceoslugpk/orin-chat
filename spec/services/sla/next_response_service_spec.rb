require 'rails_helper'

RSpec.describe Sla::NextResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:policy) do
    create(
      :sla_policy,
      account: account,
      first_response_time_threshold: 3600,
      next_response_time_threshold: 900,
      resolution_time_threshold: 7200
    )
  end

  before do
    account.enable_features!('sla')
    conversation.update!(sla_policy: policy)
  end

  it 'sets the next response due time and schedules a check when the customer is waiting' do
    conversation.update!(first_reply_created_at: 1.hour.ago)

    expect do
      conversation.update!(waiting_since: 10.minutes.ago)
    end.to have_enqueued_job(Sla::BreachJob).with(conversation.applied_sla.id, :nrt)

    expect(conversation.applied_sla.sla_nrt_due_at).to be_within(2.seconds).of(
      conversation.waiting_since + policy.next_response_time_threshold.seconds
    )
  end

  it 'does not start the next response clock before the first reply' do
    conversation.update!(waiting_since: 10.minutes.ago)

    expect(conversation.applied_sla.sla_nrt_due_at).to be_nil
  end

  it 'clears the next response due time when the waiting period ends' do
    conversation.update!(first_reply_created_at: 1.hour.ago)
    conversation.update!(waiting_since: 10.minutes.ago)
    expect(conversation.applied_sla.sla_nrt_due_at).to be_present

    conversation.update!(waiting_since: nil)

    expect(conversation.applied_sla.reload.sla_nrt_due_at).to be_nil
  end

  it 'uses business hours for the next response deadline' do
    inbox.update!(working_hours_enabled: true)
    policy.update!(only_during_business_hours: true, next_response_time_threshold: 3600)

    travel_to Time.zone.parse('2026-11-20 16:30:00') do
      conversation.update!(sla_policy: policy)
      conversation.update!(first_reply_created_at: 1.hour.ago)
      conversation.update!(waiting_since: Time.zone.parse('2026-11-20 16:30:00'))

      expect(conversation.applied_sla.sla_nrt_due_at).to eq(Time.zone.parse('2026-11-23 09:30:00'))
    end
  end
end
