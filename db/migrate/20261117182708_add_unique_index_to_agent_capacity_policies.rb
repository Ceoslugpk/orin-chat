class AddUniqueIndexToAgentCapacityPolicies < ActiveRecord::Migration[8.0]
  def change
    add_index :agent_capacity_policies, [:account_id, :name], unique: true
  end
end
