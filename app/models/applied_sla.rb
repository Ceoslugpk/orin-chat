class AppliedSla < ApplicationRecord
  belongs_to :account
  belongs_to :sla_policy
  belongs_to :conversation
  has_many :sla_events, dependent: :destroy_async

  enum :sla_status, { active: 0, hit: 1, missed: 2, active_with_misses: 3 }

  validates :sla_policy_id, uniqueness: { scope: [:account_id, :conversation_id] }
  validate :related_records_share_account

  private

  def related_records_share_account
    return if sla_policy&.account_id == account_id && conversation&.account_id == account_id

    errors.add(:base, :account_mismatch)
  end
end
