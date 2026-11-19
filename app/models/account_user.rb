# == Schema Information
#
# Table name: account_users
#
#  id                       :bigint           not null, primary key
#  accepts_calls            :boolean          default(TRUE), not null
#  accepts_conversations    :boolean          default(TRUE), not null
#  active_at                :datetime
#  auto_offline             :boolean          default(TRUE), not null
#  availability             :integer          default("online"), not null
#  role                     :integer          default("agent")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint
#  agent_capacity_policy_id :bigint
#  custom_role_id           :bigint
#  inviter_id               :bigint
#  user_id                  :bigint
#
# Indexes
#
#  index_account_users_on_account_id                (account_id)
#  index_account_users_on_agent_capacity_policy_id  (agent_capacity_policy_id)
#  index_account_users_on_custom_role_id            (custom_role_id)
#  index_account_users_on_user_id                   (user_id)
#  uniq_user_id_per_account_id                      (account_id,user_id) UNIQUE
#

class AccountUser < ApplicationRecord
  include AvailabilityStatusable

  CONVERSATION_ACCESS_SCOPES = {
    'conversation_manage' => :all,
    'conversation_unassigned_manage' => :unassigned,
    'conversation_participating_manage' => :participating
  }.freeze

  belongs_to :account
  belongs_to :user
  belongs_to :inviter, class_name: 'User', optional: true
  belongs_to :custom_role, optional: true
  belongs_to :agent_capacity_policy, optional: true

  enum :role, { agent: 0, administrator: 1 }
  enum :availability, { online: 0, offline: 1, busy: 2 }

  accepts_nested_attributes_for :account

  after_create_commit :notify_creation, :create_notification_setting
  after_destroy :notify_deletion, :remove_user_from_account
  after_save :update_presence_in_redis, if: :saved_change_to_availability?
  after_commit :invalidate_filtered_unread_count_visibility, on: [:create, :destroy]
  after_update_commit :invalidate_filtered_unread_count_visibility_update, if: :filtered_unread_count_visibility_changed?
  after_commit :notify_permissions_changed, on: [:create, :destroy]
  after_update_commit :notify_permissions_changed_on_update, if: :filtered_unread_count_visibility_changed?

  validates :user_id, uniqueness: { scope: :account_id }
  validate :accepts_conversations_or_calls
  validate :validate_custom_role_link, if: :custom_role_link_changed?
  validate :agent_capacity_policy_belongs_to_account

  def create_notification_setting
    setting = user.notification_settings.new(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_assignment]
    setting.selected_push_flags = [:push_conversation_assignment]
    setting.save!
  end

  def remove_user_from_account
    ::Agents::DestroyJob.perform_later(account, user)
  end

  def permissions
    return ['administrator'] if administrator?
    return ['agent'] unless uses_custom_role_permissions?

    effective_custom_role_permissions
  end

  def uses_custom_role_permissions?
    agent? && custom_role_id.present? && account.feature_enabled?('custom_roles')
  end

  def conversation_access_scopes
    return [:all] unless uses_custom_role_permissions?

    permissions.filter_map { |permission| CONVERSATION_ACCESS_SCOPES[permission] }.uniq
  end

  def contact_access?
    !uses_custom_role_permissions? || permissions.include?('contact_manage')
  end

  def push_event_data
    {
      id: id,
      availability: availability,
      role: role,
      user_id: user_id
    }
  end

  def available_capacity_for(inbox)
    policy = agent_capacity_policy
    return if policy.blank? || policy.account_id != account_id

    policy.available_capacity_for(self, inbox)
  end

  def capacity_available_for?(inbox)
    available_capacity_for(inbox) != 0
  end

  private

  def agent_capacity_policy_belongs_to_account
    return if agent_capacity_policy.blank? || agent_capacity_policy.account_id == account_id

    errors.add(:agent_capacity_policy, :invalid)
  end

  def effective_custom_role_permissions
    linked_role = custom_role
    return [] unless linked_role && linked_role.account_id == account_id

    permissions = Array(linked_role.permissions)
    return [] if permissions.include?('administrator')

    permissions
  end

  def custom_role_link_changed?
    new_record? || will_save_change_to_custom_role_id? || will_save_change_to_account_id? || will_save_change_to_role? ||
      association(:custom_role).target&.new_record?
  end

  def validate_custom_role_link
    linked_role = custom_role
    return if custom_role_id.nil? && linked_role.nil?

    error = if linked_role.nil?
              'missing'
            elsif linked_role.account != account
              'account_mismatch'
            elsif !agent?
              'agent_only'
            end
    errors.add(:custom_role, I18n.t("errors.account_user.custom_role.#{error}")) if error
  end

  def notify_creation
    Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account)
  end

  def notify_deletion
    Rails.configuration.dispatcher.dispatch(AGENT_REMOVED, Time.zone.now, account: account)
  end

  def update_presence_in_redis
    OnlineStatusTracker.set_status(account.id, user.id, availability)
  end

  def filtered_unread_count_visibility_changed?
    previous_changes.key?('role') || previous_changes.key?('custom_role_id')
  end

  def invalidate_filtered_unread_count_visibility
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).user_visibility_changed!(user_id: user_id)
  end

  def notify_permissions_changed
    return unless account.feature_enabled?('custom_roles')

    Rails.configuration.dispatcher.dispatch(ACCOUNT_PERMISSIONS_CHANGED, Time.zone.now, account: account, user_id: user_id)
  end

  def notify_permissions_changed_on_update
    notify_permissions_changed
  end

  def invalidate_filtered_unread_count_visibility_update
    dispatch_account_cache_invalidated if invalidate_filtered_unread_count_visibility
  end

  def dispatch_account_cache_invalidated
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
  end

  def accepts_conversations_or_calls
    return if accepts_conversations || accepts_calls

    errors.add(:base, I18n.t('errors.account_user.no_work_preference'))
  end
end

AccountUser.prepend_mod_with('AccountUser')
AccountUser.include_mod_with('Audit::AccountUser')
AccountUser.include_mod_with('Concerns::AccountUser')
