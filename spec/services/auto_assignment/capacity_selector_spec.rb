require 'rails_helper'

RSpec.describe AutoAssignment::CapacitySelector do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assignment_policy) { create(:assignment_policy, account: account, assignment_order: :balanced) }
  let(:selector) { described_class.new(inbox: inbox) }

  before do
    account.enable_features!('advanced_assignment')
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: assignment_policy)
  end

  def prepare_agent(limit:, open_conversations: 0)
    agent = create(:user, account: account)
    create(:inbox_member, inbox: inbox, user: agent)
    capacity_policy = create(:agent_capacity_policy, account: account)
    create(:inbox_capacity_limit, agent_capacity_policy: capacity_policy, inbox: inbox, conversation_limit: limit)
    agent.account_users.find_by!(account: account).update!(agent_capacity_policy: capacity_policy)
    open_conversations.times do
      create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open)
    end
    agent
  end

  it 'selects the agent with the most remaining capacity' do
    roomy_agent = prepare_agent(limit: 5)
    busy_agent = prepare_agent(limit: 5, open_conversations: 2)

    selected = selector.select_agent(inbox.inbox_members.includes(:user))

    expect(selected).to eq(roomy_agent)
    expect(selected).not_to eq(busy_agent)
  end

  it 'returns nil when no agents are available' do
    expect(selector.select_agent([])).to be_nil
  end
end
