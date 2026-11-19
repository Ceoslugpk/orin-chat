class Notification::DeliveryGuard
  attr_reader :notification

  def initialize(notification:)
    @notification = notification
  end

  def allowed?
    return true unless account&.feature_enabled?('custom_roles')

    conversation = notification.conversation
    return true if conversation.blank?

    account_user = account.account_users.find_by(user_id: notification.user_id)
    Conversations::AccessService.new(conversation: conversation).allowed?(notification.user, account_user)
  end

  private

  def account
    @account ||= Account.find_by(id: notification.account_id)
  end
end
