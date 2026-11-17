class SlaEvent < ApplicationRecord
  belongs_to :applied_sla
  belongs_to :conversation
  belongs_to :account
  belongs_to :sla_policy
  belongs_to :inbox

  enum :event_type, { frt: 0, nrt: 1, rt: 2 }

  validates :event_type, presence: true
end
