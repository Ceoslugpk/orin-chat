class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account, plan_hint_selective_filter: false)
    @conversations = conversations
    @user = user
    @account = account
    @plan_hint_selective_filter = plan_hint_selective_filter
  end

  def perform
    return conversations if administrator?
    return role_scoped_conversations if restricted_role?

    accessible_conversations
  end

  private

  def role_scoped_conversations
    scope = inbox_scoped_conversations
    scopes = account_user.conversation_access_scopes
    return scope.none if scopes.empty?
    return scope if scopes.include?(:all)

    apply_conversation_access_scopes(scope, scopes)
  end

  def apply_conversation_access_scopes(scope, scopes)
    conditions = []
    conditions << scope.where(assignee_id: user.id) if scopes.intersect?(%i[unassigned participating])
    conditions << scope.unassigned if scopes.include?(:unassigned)
    conditions << scope.where(id: participant_conversation_ids) if scopes.include?(:participating)

    conditions.reduce { |combined, condition| combined.or(condition) }
  end

  def participant_conversation_ids
    ConversationParticipant.where(account_id: account.id, user_id: user.id).select(:conversation_id)
  end

  def accessible_conversations
    return hinted_accessible_conversations if @plan_hint_selective_filter

    inbox_scoped_conversations
  end

  def inbox_scoped_conversations
    conversations.where(inbox: user.inboxes.where(account_id: account.id))
  end

  # Same rows as accessible_conversations. `inbox_id + 0` keeps the planner from
  # driving the query through an inbox scan, which it grossly misestimates when a
  # highly selective filter (e.g. labels) is present on large accounts (CW-7787).
  def hinted_accessible_conversations
    conversations.where(
      '(conversations.inbox_id + 0) IN (
        SELECT inbox_members.inbox_id FROM inbox_members
        INNER JOIN inboxes ON inboxes.id = inbox_members.inbox_id
        WHERE inbox_members.user_id = :user_id AND inboxes.account_id = :account_id
      )',
      user_id: user.id, account_id: account.id
    )
  end

  def account_user
    return unless user.is_a?(User)

    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def administrator?
    account_user&.administrator? || false
  end

  def restricted_role?
    account_user&.uses_custom_role_permissions? || false
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
