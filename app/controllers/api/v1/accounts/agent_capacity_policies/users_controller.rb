class Api::V1::Accounts::AgentCapacityPolicies::UsersController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(AgentCapacityPolicy) }
  before_action :ensure_advanced_assignment
  before_action :fetch_agent_capacity_policy

  def index
    @users = @agent_capacity_policy.account_users.agent.includes(:user).order('users.name')
  end

  def create
    @account_user = Current.account.account_users.agent.find_by!(user_id: params[:user_id])
    @account_user.update!(agent_capacity_policy: @agent_capacity_policy)
  end

  def destroy
    account_user = @agent_capacity_policy.account_users.agent.find_by!(user_id: params[:id])
    account_user.update!(agent_capacity_policy: nil)
    head :ok
  end

  private

  def ensure_advanced_assignment
    head :not_found unless Current.account.feature_enabled?('advanced_assignment')
  end

  def fetch_agent_capacity_policy
    @agent_capacity_policy = Current.account.agent_capacity_policies.find(params[:agent_capacity_policy_id])
  end
end
