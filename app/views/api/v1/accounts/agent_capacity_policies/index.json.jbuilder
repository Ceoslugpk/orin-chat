json.array! @agent_capacity_policies do |agent_capacity_policy|
  json.partial! 'agent_capacity_policy', agent_capacity_policy: agent_capacity_policy
end
