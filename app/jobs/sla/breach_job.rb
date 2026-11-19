class Sla::BreachJob < ApplicationJob
  queue_as :default

  def perform(applied_sla_id, event_type)
    applied_sla = AppliedSla.find_by(id: applied_sla_id)
    return if applied_sla.blank?

    Sla::BreachService.new(applied_sla, event_type.to_sym).perform
  end
end
