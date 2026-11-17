require 'rails_helper'

RSpec.describe Sla::ApplyPolicyService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'UTC') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:policy) do
    create(
      :sla_policy,
      account: account,
      first_response_time_threshold: 3600,
      next_response_time_threshold: nil,
      resolution_time_threshold: 7200
    )
  end

  it 'creates an active applied SLA with due timestamps when the feature is enabled' do
    account.enable_features!('sla')

    conversation.update!(sla_policy: policy)

    applied_sla = conversation.applied_slas.find_by!(sla_policy: policy)
    expect(applied_sla).to be_active
    expect(applied_sla.sla_frt_due_at).to be_within(5.seconds).of(applied_sla.created_at + 1.hour)
    expect(applied_sla.sla_nrt_due_at).to be_nil
    expect(applied_sla.sla_rt_due_at).to be_within(5.seconds).of(applied_sla.created_at + 2.hours)
  end

  it 'does not apply a policy while the feature is disabled' do
    expect { conversation.update!(sla_policy: policy) }.not_to change(AppliedSla, :count)
  end

  it 'does not duplicate the applied SLA when the policy is re-selected' do
    account.enable_features!('sla')
    conversation.update!(sla_policy: policy)

    expect { conversation.update!(sla_policy: policy) }.not_to change(AppliedSla, :count)
  end

  it 'respects business hours when the policy requires them' do
    account.enable_features!('sla')
    inbox.update!(working_hours_enabled: true)
    policy.update!(only_during_business_hours: true)

    travel_to Time.zone.parse('2026-11-16 18:00:00') do
      conversation.update!(sla_policy: policy)

      applied_sla = conversation.applied_slas.find_by!(sla_policy: policy)
      expect(applied_sla.sla_frt_due_at).to eq(Time.zone.parse('2026-11-17 10:00:00'))
    end
  end
end
