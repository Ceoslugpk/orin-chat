class ActionCableBroadcastJob < ApplicationJob
  queue_as :critical
  include Events::Types

  CONVERSATION_UPDATE_EVENTS = [
    CONVERSATION_READ,
    CONVERSATION_UPDATED,
    TEAM_CHANGED,
    ASSIGNEE_CHANGED,
    CONVERSATION_STATUS_CHANGED
  ].freeze

  CONVERSATION_DATA_EVENTS = (CONVERSATION_UPDATE_EVENTS + [
    CONVERSATION_CREATED,
    CONVERSATION_BOT_HANDOFF,
    CONVERSATION_CONTACT_CHANGED,
    CONVERSATION_MENTIONED
  ]).freeze

  MESSAGE_DATA_EVENTS = [MESSAGE_CREATED, MESSAGE_UPDATED, FIRST_REPLY_CREATED].freeze
  TYPING_EVENTS = [CONVERSATION_TYPING_ON, CONVERSATION_TYPING_OFF].freeze
  NOTIFICATION_EVENTS = [NOTIFICATION_CREATED, NOTIFICATION_UPDATED].freeze
  CONTACT_DATA_EVENTS = [CONTACT_CREATED, CONTACT_UPDATED, CONTACT_MERGED, CONTACT_DELETED].freeze

  # widget_members are web widget sessions. They get widget_data, or the widget payload of a refreshed conversation.
  def perform(members, event_name, data, widget_members: [], widget_data: nil)
    return if members.blank? && widget_members.blank?

    conversation = conversation_for(event_name, data)
    members = filtered_members(members, event_name, data, conversation)
    broadcast_data = conversation && CONVERSATION_UPDATE_EVENTS.include?(event_name) ? refreshed_data(conversation, event_name, data) : data
    broadcast_to_members(members, event_name, broadcast_data)
    broadcast_to_members(widget_members, event_name, conversation ? refreshed_widget_data(conversation, data) : widget_data)
  end

  private

  def conversation_for(event_name, data)
    account = Account.find_by(id: data[:account_id] || data['account_id'])
    return if account.blank?

    display_id = conversation_display_id(event_name, data)
    return if display_id.blank?

    account.conversations.find_by(display_id: display_id)
  end

  def conversation_display_id(event_name, data)
    return notification_conversation_display_id(data) if NOTIFICATION_EVENTS.include?(event_name)
    return message_conversation_display_id(data) if MESSAGE_DATA_EVENTS.include?(event_name)
    return typing_conversation_display_id(data) if TYPING_EVENTS.include?(event_name)
    return unless CONVERSATION_DATA_EVENTS.include?(event_name)

    data[:id] || data['id']
  end

  def notification_conversation_display_id(data)
    notification = data[:notification] || data['notification']
    return unless notification && notification_primary_actor_type(notification) == 'Conversation'

    notification_record(notification, data)&.conversation&.display_id
  end

  def notification_primary_actor_type(notification)
    notification[:primary_actor_type] || notification['primary_actor_type']
  end

  def notification_record(notification, data)
    Notification.find_by(
      id: notification[:id] || notification['id'],
      account_id: data[:account_id] || data['account_id']
    )
  end

  def message_conversation_display_id(data)
    data[:conversation_id] || data['conversation_id']
  end

  def typing_conversation_display_id(data)
    conversation = data[:conversation] || data['conversation']
    conversation && (conversation[:id] || conversation['id'])
  end

  def filtered_members(members, event_name, data, conversation)
    return authorized_contact_members(members, data[:account_id] || data['account_id']) if CONTACT_DATA_EVENTS.include?(event_name)
    return authorized_members(members, conversation) if conversation.present?

    members
  end

  def authorized_contact_members(members, account_id)
    return members if members.blank?

    account = Account.find_by(id: account_id)
    return members if account.blank? || !account.feature_enabled?('custom_roles')

    users_by_token = User.where(pubsub_token: members).index_by(&:pubsub_token)
    return members if users_by_token.empty?

    allowed_contact_tokens(account, members, users_by_token)
  end

  def allowed_contact_tokens(account, members, users_by_token)
    account_users = account.account_users.where(user_id: users_by_token.values.map(&:id)).index_by(&:user_id)
    allowed_tokens = users_by_token.filter_map do |token, user|
      token if account_users[user.id]&.contact_access?
    end

    (members - users_by_token.keys) + allowed_tokens
  end

  def authorized_members(members, conversation)
    return members if members.blank? || conversation.blank? || !conversation.account.feature_enabled?('custom_roles')

    users_by_token = User.where(pubsub_token: members).index_by(&:pubsub_token)
    return members if users_by_token.empty?

    (members - users_by_token.keys) + allowed_user_tokens(conversation, users_by_token)
  end

  def allowed_user_tokens(conversation, users_by_token)
    account_users = conversation.account.account_users.where(user_id: users_by_token.values.map(&:id)).index_by(&:user_id)
    access = Conversations::AccessService.new(conversation: conversation)
    users_by_token.filter_map do |token, user|
      token if access.allowed?(user, account_users[user.id])
    end
  end

  def refreshed_data(conversation, event_name, data)
    broadcast_data = conversation.push_event_data.merge(account_id: data[:account_id])
    if event_name == ASSIGNEE_CHANGED
      # Keep the original assignment together even when the conversation is
      # refreshed. The dashboard checks its identity against the current owner.
      # Other events omit this field so unrelated updates cannot overwrite it.
      broadcast_data[:assignment] = {
        automatic: data[:automatic_assignment] == true,
        assignee_id: data.dig(:meta, :assignee, :id),
        assignee_type: data.dig(:meta, :assignee_type),
        updated_at: data[:updated_at]
      }
    end
    broadcast_data
  end

  def refreshed_widget_data(conversation, data)
    conversation.widget_push_event_data.merge(account_id: data[:account_id])
  end

  def broadcast_to_members(members, event_name, broadcast_data)
    members.each do |member|
      ActionCable.server.broadcast(
        member,
        {
          event: event_name,
          data: broadcast_data
        }
      )
    end
  end
end
