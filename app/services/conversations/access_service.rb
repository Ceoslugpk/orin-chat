class Conversations::AccessService
  attr_reader :conversation

  def initialize(conversation:)
    @conversation = conversation
  end

  def allowed?(user, account_user)
    return true if account_user&.administrator?
    return false if user.is_a?(AgentBot)

    if account_user&.uses_custom_role_permissions?
      restricted_role_allowed?(user.id, account_user)
    else
      inbox_member?(user.id) || team_member?(user.id)
    end
  end

  private

  def restricted_role_allowed?(user_id, account_user)
    scopes = account_user.conversation_access_scopes
    return false if scopes.empty? || !inbox_member?(user_id)
    return true if scopes.include?(:all)

    assignment_scope_allowed?(user_id, scopes)
  end

  def assignment_scope_allowed?(user_id, scopes)
    return true if scopes.include?(:unassigned) && unassigned?
    return true if scopes.include?(:participating) && participant_ids.include?(user_id)

    assigned_to_user?(user_id) && scopes.intersect?(%i[unassigned participating])
  end

  def inbox_member?(user_id)
    inbox_member_ids.include?(user_id)
  end

  def team_member?(user_id)
    team_member_ids.include?(user_id)
  end

  def assigned_to_user?(user_id)
    conversation.assignee_id == user_id
  end

  def unassigned?
    conversation.assignee_id.nil? && conversation.assignee_agent_bot_id.nil?
  end

  def inbox_member_ids
    @inbox_member_ids ||= conversation.inbox.members.pluck(:id)
  end

  def team_member_ids
    @team_member_ids ||= conversation.team_id.present? ? conversation.team.members.pluck(:id) : []
  end

  def participant_ids
    @participant_ids ||= conversation.conversation_participants.pluck(:user_id)
  end
end
