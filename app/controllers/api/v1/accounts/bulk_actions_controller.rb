class Api::V1::Accounts::BulkActionsController < Api::V1::Accounts::BaseController
  before_action :validate_assignment_targets, only: :create, if: -> { normalized_type == 'Conversation' }
  before_action :validate_required_attributes, only: :create, if: -> { resolving_conversations? }

  def create
    case normalized_type
    when 'Conversation'
      enqueue_conversation_job
      head :ok
    when 'Contact'
      authorize_contact_action
      enqueue_contact_job
      head :ok
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end

  private

  def normalized_type
    params[:type].to_s.camelize
  end

  def validate_assignment_targets
    fields = conversation_params[:fields] || {}

    assignee_id = fields[:assignee_id]
    return render_could_not_create_error('Invalid assignee_id') if !assignee_id.nil? && !@current_account.users.exists?(id: assignee_id)

    team_id = fields[:team_id]
    # The dashboard sends 0 to remove the team assignment; accept '0' from form-encoded requests too.
    return if [nil, 0, '0'].include?(team_id) || @current_account.teams.exists?(id: team_id)

    render_could_not_create_error('Invalid team_id')
  end

  def resolving_conversations?
    normalized_type == 'Conversation' && conversation_params.dig(:fields, :status).to_s == 'resolved'
  end

  def validate_required_attributes
    scope = @current_account.conversations.where(display_id: params[:ids])
    scope = Conversations::PermissionFilterService.new(scope, current_user, @current_account).perform

    missing = scope.filter_map do |conversation|
      attributes = Conversations::RequiredAttributesService.new(conversation).missing_attributes
      { id: conversation.display_id, missing_attributes: attributes } if attributes.any?
    end
    return if missing.empty?

    render json: {
      error: I18n.t('errors.conversation.required_attributes_missing'),
      conversations: missing
    }, status: :unprocessable_content
  end

  def enqueue_conversation_job
    ::BulkActionsJob.perform_later(
      account: @current_account,
      user: current_user,
      params: conversation_params
    )
  end

  def enqueue_contact_job
    Contacts::BulkActionJob.perform_later(
      @current_account.id,
      current_user.id,
      contact_params
    )
  end

  def delete_contact_action?
    params[:action_name] == 'delete'
  end

  def authorize_contact_action
    authorize(Contact, delete_contact_action? ? :destroy? : :update?)
  end

  def conversation_params
    # TODO: Align conversation payloads with the `{ action_name, action_attributes }`
    # and then remove this method in favor of a common params method.
    base = params.permit(
      :snoozed_until,
      fields: [:status, :assignee_id, :team_id]
    )
    append_common_bulk_attributes(base)
  end

  def contact_params
    # TODO: remove this method in favor of a common params method.
    # once legacy conversation payloads are migrated.
    append_common_bulk_attributes({})
  end

  def append_common_bulk_attributes(base_params)
    # NOTE: Conversation payloads historically diverged per action. Going forward we
    # want all objects to share a common contract: `{ action_name, action_attributes }`
    common = params.permit(:type, :action_name, ids: [], labels: [add: [], remove: []])
    base_params.merge(common)
  end
end
