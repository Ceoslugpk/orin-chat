class Sla::NextResponseService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    return unless conversation.account.feature_enabled?('sla')

    applied_sla = conversation.applied_sla
    return unless applied_sla
    return unless applied_sla.active? || applied_sla.active_with_misses?

    if next_response_pending?
      update_due_at(applied_sla)
    elsif applied_sla.sla_nrt_due_at.present?
      applied_sla.update!(sla_nrt_due_at: nil)
    end
  end

  private

  attr_reader :conversation

  def next_response_pending?
    conversation.first_reply_created_at.present? && conversation.waiting_since.present?
  end

  def update_due_at(applied_sla)
    due_at = calculator(applied_sla).add(
      applied_sla.sla_policy.next_response_time_threshold,
      from: conversation.waiting_since
    )
    applied_sla.update!(sla_nrt_due_at: due_at)
    Sla::ScheduleBreachChecksService.new(applied_sla).schedule(:nrt)
  end

  def calculator(applied_sla)
    Sla::DueAtCalculator.new(policy: applied_sla.sla_policy, inbox: conversation.inbox)
  end
end
