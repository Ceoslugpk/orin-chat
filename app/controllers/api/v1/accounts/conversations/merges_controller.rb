class Api::V1::Accounts::Conversations::MergesController < Api::V1::Accounts::Conversations::BaseController
  def create
    target = Current.account.conversations.find_by!(display_id: params[:target_conversation_id])
    authorize target, :show?

    merged = Conversations::MergeService.new(
      source: @conversation,
      target: target,
      user: Current.user
    ).perform

    render json: { merged_into: { id: merged.display_id, uuid: merged.uuid } }
  rescue Conversations::MergeService::InvalidMerge => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def conversation
    @conversation ||= Current.account.conversations.find_by!(display_id: params[:id])
    authorize @conversation, :show?
  end
end
