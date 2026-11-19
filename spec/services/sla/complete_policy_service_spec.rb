require 'rails_helper'

RSpec.describe Sla::CompletePolicyService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'UTC') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:policy) do
    create(
      :sla_policy,
      account: account,
      first_response_time_threshold: 3600,
      next_response_time_threshold: nil,
      resolution_time_threshold: 7200,
      only_during_business_hours: false
    )
  end
  let(:applied_sla) { conversation.applied_slas.find_by!(sla_policy: policy) }

  before do
    account.enable_features!('sla')
    conversation.update!(sla_policy: policy)
  end

  it 'marks a policy hit when first response and resolution are in time' do
    applied_sla.update!(sla_frt_due_at: 30.minutes.from_now, sla_rt_due_at: 1.hour.from_now)
    conversation.update!(first_reply_created_at: 10.minutes.ago)

    conversation.update!(status: :resolved)

    expect(applied_sla.reload).to be_hit
    expect(applied_sla.completed_at).to be_present
    expect(applied_sla.sla_events).to be_empty
  end

  it 'records a first-response miss when no reply is sent before resolution' do
    applied_sla.update!(sla_frt_due_at: 1.minute.ago, sla_rt_due_at: 1.hour.from_now)

    conversation.update!(status: :resolved)

    expect(applied_sla.reload).to be_missed
    expect(applied_sla.sla_events.pluck(:event_type)).to eq(['frt'])
  end

  it 'records a resolution miss when resolved after the due time' do
    applied_sla.update!(sla_frt_due_at: 1.hour.from_now, sla_rt_due_at: 1.minute.ago)
    conversation.update!(first_reply_created_at: 10.minutes.ago)

    conversation.update!(status: :resolved)

    expect(applied_sla.reload).to be_missed
    expect(applied_sla.sla_events.pluck(:event_type)).to eq(['rt'])
  end

  it 'does not duplicate miss events on a second completion' do
    applied_sla.update!(sla_frt_due_at: 1.minute.ago, sla_rt_due_at: 1.hour.from_now)
    conversation.update!(status: :resolved)
    completed_at = applied_sla.reload.completed_at

    expect { described_class.new(conversation).perform }.not_to change(SlaEvent, :count)

    expect(applied_sla.reload).to be_missed
    expect(applied_sla.completed_at).to be_within(1.second).of(completed_at)
  end

  it 'does nothing while the account feature is disabled' do
    applied_sla.update!(sla_frt_due_at: 1.minute.ago, sla_rt_due_at: 1.hour.from_now)
    account.disable_features!('sla')

    conversation.update!(status: :resolved)

    expect(applied_sla.reload).to be_active
    expect(SlaEvent.count).to be_zero
  end
end
