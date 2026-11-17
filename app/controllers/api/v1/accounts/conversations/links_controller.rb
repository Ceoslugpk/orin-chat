class Api::V1::Accounts::Conversations::LinksController < Api::V1::Accounts::Conversations::BaseController
  before_action :fetch_linked_conversation, only: :create
  before_action :fetch_link, only: :destroy

  def index
    @links = ConversationLink.where(account_id: Current.account.id)
                             .where('conversation_id = :id OR linked_conversation_id = :id', id: @conversation.id)
                             .includes(:conversation, :linked_conversation)
                             .order(created_at: :desc)
  end

  def create
    authorize @linked_conversation, :show?
    @link = ConversationLink.link!(
      account: Current.account,
      conversation: @conversation,
      linked_conversation: @linked_conversation,
      user: Current.user
    )
    render :show, status: :created
  end

  def destroy
    authorize @link.conversation, :show?
    authorize @link.linked_conversation, :show?
    @link.destroy!
    head :ok
  end

  private

  def fetch_linked_conversation
    @linked_conversation = Current.account.conversations.find_by!(display_id: params[:linked_conversation_id])
  end

  def fetch_link
    @link = ConversationLink.where(account_id: Current.account.id).find(params[:id])
  end
end
