class RoomChannel < ApplicationCable::Channel
  def subscribed
    # TODO: should we only do ensure stream  if current account is present?
    # for now going ahead with guard clauses in update_subscription and broadcast_presence
    current_user
    current_account
    ensure_stream
    update_subscription
    broadcast_presence
  end

  def update_presence
    update_subscription
    broadcast_presence
  end

  private

  def broadcast_presence
    return if @current_account.blank?

    membership = current_account_user
    data = { account_id: @current_account.id, users: available_users(membership) }
    if @current_user.is_a?(User) && membership.present?
      data[:contacts] = ::OnlineStatusTracker.get_available_contacts(@current_account.id) if membership.contact_access?
      data[:work_preferences] = membership.slice(:accepts_conversations, :accepts_calls)
    end
    ActionCable.server.broadcast(pubsub_token, { event: 'presence.update', data: data })
  end

  def available_users(membership)
    users = ::OnlineStatusTracker.get_available_users(@current_account.id)
    return users unless @current_user.is_a?(User)
    return {} if membership.blank?
    return users unless membership.uses_custom_role_permissions?

    users.slice(*visible_user_ids.map(&:to_s))
  end

  def visible_user_ids
    inbox_ids = @current_user.inboxes.where(account_id: @current_account.id).pluck(:id)
    member_ids = InboxMember.where(inbox_id: inbox_ids).pluck(:user_id)
    (member_ids + @current_account.administrators.pluck(:id) + [@current_user.id]).uniq
  end

  def current_account_user
    return unless @current_user.is_a?(User)

    @current_user.account_users.find_by(account_id: @current_account.id)
  end

  def ensure_stream
    stream_from pubsub_token
    stream_from "account_#{@current_account.id}" if @current_account.present? && @current_user.is_a?(User)
  end

  def update_subscription
    return if @current_account.blank?

    ::OnlineStatusTracker.update_presence(@current_account.id, @current_user.class.name, @current_user.id)
  end

  def pubsub_token
    @pubsub_token ||= params[:pubsub_token]
  end

  def current_user
    @current_user ||= if params[:user_id].blank?
                        ContactInbox.find_by!(pubsub_token: pubsub_token).contact
                      else
                        User.find_by!(pubsub_token: pubsub_token, id: params[:user_id])
                      end
  end

  def current_account
    return if current_user.blank?

    @current_account ||= if @current_user.is_a? Contact
                           @current_user.account
                         else
                           @current_user.accounts.find(params[:account_id])
                         end
  end
end
