class Api::V1::Accounts::AgentCapacityPoliciesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :ensure_advanced_assignment
  before_action :fetch_agent_capacity_policy, only: [:show, :update, :destroy]

  def index
    @agent_capacity_policies = Current.account.agent_capacity_policies
                                      .includes(:inbox_capacity_limits, account_users: :user)
                                      .order(:name)
  end

  def show; end

  def create
    @agent_capacity_policy = Current.account.agent_capacity_policies.create!(agent_capacity_policy_params)
    render :show, status: :created
  end

  def update
    @agent_capacity_policy.update!(agent_capacity_policy_params)
    render :show
  end

  def destroy
    @agent_capacity_policy.destroy!
    head :ok
  end

  private

  def ensure_advanced_assignment
    head :not_found unless Current.account.feature_enabled?('advanced_assignment')
  end

  def fetch_agent_capacity_policy
    @agent_capacity_policy = Current.account.agent_capacity_policies
                                    .includes(:inbox_capacity_limits, account_users: :user)
                                    .find(params[:id])
  end

  def agent_capacity_policy_params
    permitted = params.require(:agent_capacity_policy).permit(:name, :description)
    rules = params.dig(:agent_capacity_policy, :exclusion_rules)
    permitted[:exclusion_rules] = normalized_exclusion_rules(rules) if rules.present?
    permitted
  end

  def normalized_exclusion_rules(rules)
    permitted = rules.permit(:exclude_older_than_hours, :excludeOlderThanHours, excluded_labels: [], excludedLabels: [])
    labels = permitted[:excluded_labels] || permitted[:excludedLabels]
    hours = permitted[:exclude_older_than_hours] || permitted[:excludeOlderThanHours]
    {
      'excluded_labels' => Array(labels).map(&:to_s),
      'exclude_older_than_hours' => Integer(hours, exception: false)
    }.compact
  end
end
