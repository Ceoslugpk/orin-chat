class Api::V1::Accounts::SlaPoliciesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_sla_policy, only: [:show, :update, :destroy]

  def index
    @sla_policies = Current.account.sla_policies.order(:name, :id)
  end

  def show; end

  def create
    @sla_policy = Current.account.sla_policies.create!(sla_policy_params)
    render :show, status: :created
  end

  def update
    @sla_policy.update!(sla_policy_params)
    render :show
  end

  def destroy
    if @sla_policy.destroy
      head :ok
    else
      render json: { error: @sla_policy.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  private

  def check_authorization
    super(SlaPolicy)
  end

  def fetch_sla_policy
    @sla_policy = Current.account.sla_policies.find(params[:id])
  end

  def sla_policy_params
    params.permit(
      :name,
      :description,
      :first_response_time_threshold,
      :next_response_time_threshold,
      :resolution_time_threshold,
      :only_during_business_hours
    )
  end
end
