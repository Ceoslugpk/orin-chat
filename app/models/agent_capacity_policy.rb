class AgentCapacityPolicy < ApplicationRecord
  belongs_to :account
  has_many :inbox_capacity_limits, dependent: :destroy_async
  has_many :inboxes, through: :inbox_capacity_limits
  has_many :account_users, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }, length: { maximum: 255 }
  validate :exclusion_rules_is_hash

  def capacity_limit_for(inbox)
    limit = if inbox_capacity_limits.loaded?
              inbox_capacity_limits.detect { |record| record.inbox_id == inbox.id }
            else
              inbox_capacity_limits.find_by(inbox_id: inbox.id)
            end
    limit&.conversation_limit
  end

  def available_capacity_for(account_user, inbox)
    limit = capacity_limit_for(inbox)
    return if limit.blank?

    [limit - open_conversation_count_for(account_user, inbox), 0].max
  end

  def capacity_available_for?(account_user, inbox)
    available_capacity_for(account_user, inbox) != 0
  end

  def open_conversation_count_for(account_user, inbox)
    scope = Conversation.where(
      account_id: account_id,
      inbox_id: inbox.id,
      assignee_id: account_user.user_id,
      status: :open
    )

    labels = excluded_labels
    scope = scope.where.not(id: excluded_conversation_ids(labels)) if labels.any?

    hours = exclude_older_than_hours
    scope = scope.where('conversations.last_activity_at >= ?', hours.hours.ago) if hours&.positive?
    scope.count
  end

  def excluded_labels
    Array(exclusion_rules['excluded_labels'] || exclusion_rules['excludedLabels']).map(&:to_s).compact_blank
  end

  def exclude_older_than_hours
    value = exclusion_rules['exclude_older_than_hours'] || exclusion_rules['excludeOlderThanHours']
    Integer(value, exception: false)
  end

  private

  def excluded_conversation_ids(labels)
    Conversation.where(account_id: account_id).tagged_with(labels, any: true).ids
  end

  def exclusion_rules_is_hash
    errors.add(:exclusion_rules, :invalid) unless exclusion_rules.is_a?(Hash)
  end
end
