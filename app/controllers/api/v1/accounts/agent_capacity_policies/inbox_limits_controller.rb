class Api::V1::Accounts::AgentCapacityPolicies::InboxLimitsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(AgentCapacityPolicy) }
  before_action :ensure_advanced_assignment
  before_action :fetch_agent_capacity_policy
  before_action :fetch_inbox_capacity_limit, only: [:update, :destroy]

  def create
    @inbox_capacity_limit = @agent_capacity_policy.inbox_capacity_limits.create!(inbox_limit_params)
    render :create, status: :created
  end

  def update
    @inbox_capacity_limit.update!(inbox_limit_params.except(:inbox_id))
    render :update
  end

  def destroy
    @inbox_capacity_limit.destroy!
    head :ok
  end

  private

  def ensure_advanced_assignment
    head :not_found unless Current.account.feature_enabled?('advanced_assignment')
  end

  def fetch_agent_capacity_policy
    @agent_capacity_policy = Current.account.agent_capacity_policies.find(params[:agent_capacity_policy_id])
  end

  def fetch_inbox_capacity_limit
    @inbox_capacity_limit = @agent_capacity_policy.inbox_capacity_limits.find(params[:id])
  end

  def inbox_limit_params
    params.permit(:inbox_id, :conversation_limit)
  end
end
