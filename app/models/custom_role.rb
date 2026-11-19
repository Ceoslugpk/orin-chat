class CustomRole < ApplicationRecord
  PERMISSIONS = %w[
    conversation_manage
    conversation_unassigned_manage
    conversation_participating_manage
    contact_manage
    report_manage
    knowledge_base_manage
  ].freeze

  belongs_to :account
  has_many :account_users, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.strip }

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, presence: true, length: { maximum: 1_000 }
  validates :permissions, presence: true
  validate :supported_permissions

  after_update_commit :invalidate_linked_member_visibility, if: :saved_change_to_permissions?

  private

  def invalidate_linked_member_visibility
    user_ids = account_users.pluck(:user_id)
    return if user_ids.empty?

    Conversations::UnreadCounts::FilteredCountInvalidator.new(account).users_visibility_changed!(user_ids: user_ids)
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
    notify_linked_members(user_ids)
  end

  def notify_linked_members(user_ids)
    return unless account.feature_enabled?('custom_roles')

    Rails.configuration.dispatcher.dispatch(ACCOUNT_PERMISSIONS_CHANGED, Time.zone.now, account: account, user_ids: user_ids)
  end

  def supported_permissions
    return if permissions.blank?
    return if permissions.is_a?(Array) && permissions.uniq == permissions && permissions.all? { |permission| PERMISSIONS.include?(permission) }

    errors.add(:permissions, :invalid)
  end
end
