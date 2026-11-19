module ActionCableListener::PermissionEvents
  include Events::Types

  def account_permissions_changed(event)
    account = event.data[:account]
    user_ids = Array(event.data[:user_id] || event.data[:user_ids]).compact.uniq
    tokens = User.where(id: user_ids).pluck(:pubsub_token)
    broadcast(account, tokens, ACCOUNT_PERMISSIONS_CHANGED, {}) if account.present? && tokens.present?
  end

  private

  def contact_event_tokens(account)
    return ["account_#{account.id}"] unless account.feature_enabled?('custom_roles')

    account.users.pluck(:pubsub_token)
  end
end
