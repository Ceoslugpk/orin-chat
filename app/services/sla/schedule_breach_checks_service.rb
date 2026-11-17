class Sla::ScheduleBreachChecksService
  DUE_ATTRIBUTES = {
    frt: :sla_frt_due_at,
    nrt: :sla_nrt_due_at,
    rt: :sla_rt_due_at
  }.freeze

  def initialize(applied_sla)
    @applied_sla = applied_sla
  end

  def perform
    return unless applied_sla.active? || applied_sla.active_with_misses?

    DUE_ATTRIBUTES.each_key { |event_type| schedule(event_type) }
  end

  def schedule(event_type)
    due_at = applied_sla.public_send(DUE_ATTRIBUTES.fetch(event_type))
    return if due_at.blank?

    Sla::BreachJob.set(wait_until: due_at).perform_later(applied_sla.id, event_type)
  end

  private

  attr_reader :applied_sla
end
