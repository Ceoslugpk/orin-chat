class Api::V1::Accounts::CustomRolesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_custom_role, only: [:show, :update, :destroy]

  def index
    @custom_roles = Current.account.custom_roles.order(:name, :id)
  end

  def show; end

  def create
    @custom_role = Current.account.custom_roles.create!(custom_role_params)
    render :show, status: :created
  end

  def update
    @custom_role.update!(custom_role_params)
    render :show
  end

  def destroy
    if @custom_role.destroy
      head :ok
    else
      render json: { error: @custom_role.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  private

  def check_authorization
    super(CustomRole)
  end

  def fetch_custom_role
    @custom_role = Current.account.custom_roles.find(params[:id])
  end

  def custom_role_params
    params.permit(:name, :description, permissions: [])
  end
end
