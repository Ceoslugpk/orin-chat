class ConversationLink < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :linked_conversation, class_name: 'Conversation'
  belongs_to :created_by, class_name: 'User', optional: true

  validates :linked_conversation_id, uniqueness: { scope: :conversation_id }
  validate :distinct_conversations, :same_account

  def self.link!(account:, conversation:, linked_conversation:, user: nil)
    first, second = [conversation, linked_conversation].sort_by(&:id)
    find_or_create_by!(account: account, conversation: first, linked_conversation: second) do |link|
      link.created_by = user
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(account: account, conversation: first, linked_conversation: second)
  end

  def other_conversation(current_conversation_id)
    conversation_id == current_conversation_id ? linked_conversation : conversation
  end

  private

  def distinct_conversations
    return if conversation_id.blank? || linked_conversation_id.blank?

    errors.add(:base, :invalid) if conversation_id == linked_conversation_id
  end

  def same_account
    return if conversation.blank? || linked_conversation.blank?

    errors.add(:base, :invalid) unless conversation.account_id == linked_conversation.account_id
  end
end
