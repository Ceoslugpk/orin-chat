module InboxAgentAvailability
  extend ActiveSupport::Concern

  def available_agents
    online_members.where(account_users: { accepts_conversations: true })
  end

  def available_call_agents
    online_members.where(account_users: { accepts_calls: true })
  end

  def member_ids_with_assignment_capacity
    return member_ids unless account.feature_enabled?('advanced_assignment')

    account_users = account.account_users.where(user_id: member_ids)
    account_users = account_users.includes(:agent_capacity_policy).index_by(&:user_id)
    member_ids.select do |user_id|
      account_user = account_users[user_id]
      account_user.nil? || account_user.capacity_available_for?(self)
    end
  end

  private

  def online_members
    online_agent_ids = fetch_online_agent_ids
    return inbox_members.none if online_agent_ids.empty?

    inbox_members
      .joins(user: :account_users)
      .where(users: { id: online_agent_ids }, account_users: { account_id: account_id })
      .includes(:user)
  end

  def fetch_online_agent_ids
    OnlineStatusTracker.get_available_users(account_id)
                       .select { |_key, value| value.eql?('online') }
                       .keys
                       .map(&:to_i)
  end
end

InboxAgentAvailability.prepend_mod_with('InboxAgentAvailability')
