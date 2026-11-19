require 'rails_helper'

RSpec.describe Sla::ReopenPolicyService do
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

  it 'reactivates a hit policy without misses' do
    applied_sla.update!(sla_frt_due_at: 30.minutes.from_now, sla_rt_due_at: 1.hour.from_now)
    conversation.update!(first_reply_created_at: 10.minutes.ago)
    conversation.update!(status: :resolved)
    expect(applied_sla.reload).to be_hit

    conversation.update!(status: :open)

    expect(applied_sla.reload).to be_active
    expect(applied_sla.completed_at).to be_nil
  end

  it 'reactivates a missed policy with its misses' do
    applied_sla.update!(sla_frt_due_at: 1.minute.ago, sla_rt_due_at: 1.hour.from_now)
    conversation.update!(status: :resolved)
    expect(applied_sla.reload).to be_missed

    conversation.update!(status: :open)

    expect(applied_sla.reload).to be_active_with_misses
    expect(applied_sla.completed_at).to be_nil
  end

  it 'does nothing while the account feature is disabled' do
    applied_sla.update!(sla_frt_due_at: 30.minutes.from_now, sla_rt_due_at: 1.hour.from_now)
    conversation.update!(first_reply_created_at: 10.minutes.ago)
    conversation.update!(status: :resolved)
    account.disable_features!('sla')

    conversation.update!(status: :pending)

    expect(applied_sla.reload).to be_hit
  end
end
