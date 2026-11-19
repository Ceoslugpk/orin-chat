class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    return true unless account_user&.uses_custom_role_permissions?

    account_user.conversation_access_scopes.any?
  end

  def destroy?
    administrator?
  end

  def show?
    return true if administrator? || agent_bot?

    Conversations::AccessService.new(conversation: record).allowed?(user, account_user)
  end

  private

  def agent_bot?
    user.is_a?(AgentBot)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
