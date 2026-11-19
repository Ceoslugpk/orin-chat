require 'rails_helper'

RSpec.describe SlaPolicy, type: :model do
  let(:account) { create(:account) }

  it 'is valid with the factory attributes' do
    expect(build(:sla_policy, account: account)).to be_valid
  end

  describe 'validations' do
    it 'requires a name of at least two characters' do
      policy = build(:sla_policy, account: account, name: ' ')

      expect(policy).not_to be_valid
      expect(policy.errors[:name]).to be_present
    end

    it 'requires at least one response or resolution threshold' do
      policy = build(
        :sla_policy,
        account: account,
        first_response_time_threshold: nil,
        next_response_time_threshold: nil,
        resolution_time_threshold: nil
      )

      expect(policy).not_to be_valid
      expect(policy.errors[:base]).to include(
        'must include at least one response or resolution time threshold'
      )
    end

    it 'accepts a policy with a single threshold' do
      policy = build(
        :sla_policy,
        account: account,
        first_response_time_threshold: nil,
        next_response_time_threshold: nil,
        resolution_time_threshold: 3600
      )

      expect(policy).to be_valid
    end

    it 'rejects non-positive thresholds' do
      policy = build(:sla_policy, account: account, first_response_time_threshold: 0)

      expect(policy).not_to be_valid
      expect(policy.errors[:first_response_time_threshold]).to be_present
    end
  end

  describe 'conversation linkage' do
    it 'clears the reference on linked conversations when removed' do
      policy = create(:sla_policy, account: account)
      conversation = create(:conversation, account: account, sla_policy: policy)

      expect { policy.destroy! }.to change { conversation.reload.sla_policy_id }.from(policy.id).to(nil)
    end
  end
end
