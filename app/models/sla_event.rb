class SlaEvent < ApplicationRecord
  belongs_to :applied_sla
  belongs_to :conversation
  belongs_to :account
  belongs_to :sla_policy
  belongs_to :inbox

  enum :event_type, { frt: 0, nrt: 1, rt: 2 }

  validates :event_type, presence: true

  def push_event_data
    {
      id: id,
      event_type: event_type,
      created_at: created_at.to_i,
      meta: meta
    }
  end
end
