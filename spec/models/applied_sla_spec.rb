require 'rails_helper'

RSpec.describe AppliedSla, type: :model do
  let(:account) { create(:account) }
  let(:policy) { create(:sla_policy, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'defaults to the active status from the factory' do
    expect(create(:applied_sla, account: account, sla_policy: policy, conversation: conversation)).to be_active
  end

  it 'allows one record per policy and conversation' do
    create(:applied_sla, account: account, sla_policy: policy, conversation: conversation)
    duplicate = build(:applied_sla, account: account, sla_policy: policy, conversation: conversation)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:sla_policy_id]).to be_present
  end

  it 'rejects records that mix accounts' do
    other_policy = create(:sla_policy)
    applied_sla = build(:applied_sla, account: account, sla_policy: other_policy, conversation: conversation)

    expect(applied_sla).not_to be_valid
    expect(applied_sla.errors[:base]).to be_present
  end
end
