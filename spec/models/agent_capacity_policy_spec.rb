require 'rails_helper'

RSpec.describe AgentCapacityPolicy, type: :model do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:account_user) { agent.account_users.find_by!(account: account) }
  let(:policy) { create(:agent_capacity_policy, account: account) }

  before do
    account.enable_features!('advanced_assignment')
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_capacity_limit, agent_capacity_policy: policy, inbox: inbox, conversation_limit: 2)
    account_user.update!(agent_capacity_policy: policy)
  end

  it 'counts open conversations assigned in the inbox against the limit' do
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open)
    expect(policy.available_capacity_for(account_user, inbox)).to eq(1)

    create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open)
    expect(policy.available_capacity_for(account_user, inbox)).to eq(0)
    expect(policy.capacity_available_for?(account_user, inbox)).to be(false)
  end

  it 'does not count resolved conversations' do
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved)

    expect(policy.available_capacity_for(account_user, inbox)).to eq(2)
  end

  it 'does not count conversations with excluded labels' do
    policy.update!(exclusion_rules: { 'excluded_labels' => ['vip'] })
    conversation = create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open)
    conversation.update!(label_list: ['vip'])

    expect(policy.available_capacity_for(account_user, inbox)).to eq(2)
  end

  it 'does not count conversations older than the exclusion window' do
    policy.update!(exclusion_rules: { 'exclude_older_than_hours' => 24 })
    conversation = create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open)
    conversation.update_column(:last_activity_at, 25.hours.ago) # rubocop:disable Rails/SkipsModelValidations

    expect(policy.available_capacity_for(account_user, inbox)).to eq(2)
  end

  it 'treats inboxes without a limit as unlimited' do
    other_inbox = create(:inbox, account: account)

    expect(policy.available_capacity_for(account_user, other_inbox)).to be_nil
    expect(policy.capacity_available_for?(account_user, other_inbox)).to be(true)
  end

  it 'rejects a capacity policy from another account' do
    foreign_policy = create(:agent_capacity_policy)
    account_user.agent_capacity_policy = foreign_policy

    expect(account_user).not_to be_valid
    expect(account_user.errors[:agent_capacity_policy]).to be_present
  end
end
