class AppliedSla < ApplicationRecord
  belongs_to :account
  belongs_to :sla_policy
  belongs_to :conversation
  has_many :sla_events, dependent: :destroy_async

  enum :sla_status, { active: 0, hit: 1, missed: 2, active_with_misses: 3 }

  scope :filter_by_created_at, ->(range) { where(created_at: range) if range.present? }
  scope :filter_by_sla_policy_id, ->(sla_policy_id) { where(sla_policy_id: sla_policy_id) if sla_policy_id.present? }
  scope :filter_by_inbox_id, lambda { |inbox_id|
    joins(:conversation).where(conversations: { inbox_id: inbox_id }) if inbox_id.present?
  }
  scope :filter_by_team_id, lambda { |team_id|
    joins(:conversation).where(conversations: { team_id: team_id }) if team_id.present?
  }
  scope :filter_by_assignee_id, lambda { |assignee_id|
    joins(:conversation).where(conversations: { assignee_id: assignee_id }) if assignee_id.present?
  }
  scope :filter_by_labels, lambda { |labels|
    next if labels.blank?

    # tagged_with forces a `SELECT *`; reselect keeps the subquery single-column.
    where(conversation_id: Conversation.tagged_with(labels, any: true).reselect(:id))
  }

  validates :sla_policy_id, uniqueness: { scope: [:account_id, :conversation_id] }
  validate :related_records_share_account

  def push_event_data
    {
      id: id,
      sla_name: sla_policy.name,
      sla_status: sla_status,
      sla_completed_at: completed_at&.to_i,
      sla_frt_due_at: sla_frt_due_at&.to_i,
      sla_nrt_due_at: sla_nrt_due_at&.to_i,
      sla_rt_due_at: sla_rt_due_at&.to_i
    }
  end

  private

  def related_records_share_account
    return if sla_policy&.account_id == account_id && conversation&.account_id == account_id

    errors.add(:base, :account_mismatch)
  end
end
