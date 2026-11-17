class AutoAssignment::CapacitySelector
  def initialize(inbox:)
    @inbox = inbox
  end

  def select_agent(available_agents)
    return if available_agents.empty?

    select_from(capacities_for(available_agents))
  end

  private

  attr_reader :inbox

  def capacities_for(available_agents)
    account_users = inbox.account.account_users
                         .where(user_id: available_agents.map(&:user_id))
                         .includes(:agent_capacity_policy)
                         .index_by(&:user_id)

    available_agents.map do |member|
      [member, account_users[member.user_id]&.available_capacity_for(inbox)]
    end
  end

  def select_from(capacities)
    unlimited = capacities.select { |_member, capacity| capacity.nil? }
    return round_robin(unlimited) if unlimited.any?

    max_capacity = capacities.map(&:last).max
    round_robin(capacities.select { |_member, capacity| capacity == max_capacity })
  end

  def round_robin(candidates)
    round_robin_selector.select_agent(candidates.map(&:first))
  end

  def round_robin_selector
    @round_robin_selector ||= AutoAssignment::RoundRobinSelector.new(inbox: inbox)
  end
end
