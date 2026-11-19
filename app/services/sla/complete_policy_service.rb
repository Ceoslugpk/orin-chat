class Sla::CompletePolicyService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    return unless conversation.account.feature_enabled?('sla')

    applied_sla = current_applied_sla
    return unless completable?(applied_sla)

    missed_types = missed_types(applied_sla)
    missed_types.each { |event_type| record_event(applied_sla, event_type) }
    applied_sla.update!(
      sla_status: completion_status(applied_sla, missed_types),
      completed_at: Time.current
    )
  end

  private

  attr_reader :conversation

  def current_applied_sla
    conversation.applied_slas.find_by(sla_policy_id: conversation.sla_policy_id)
  end

  def completable?(applied_sla)
    applied_sla && (applied_sla.active? || applied_sla.active_with_misses?)
  end

  def missed_types(applied_sla)
    [].tap do |types|
      types << :frt if first_response_missed?(applied_sla)
      types << :rt if resolution_missed?(applied_sla)
    end
  end

  def completion_status(applied_sla, missed_types)
    missed_types.any? || applied_sla.sla_events.exists? ? :missed : :hit
  end

  def first_response_missed?(applied_sla)
    return false if applied_sla.sla_frt_due_at.blank?

    conversation.first_reply_created_at.blank? || conversation.first_reply_created_at > applied_sla.sla_frt_due_at
  end

  def resolution_missed?(applied_sla)
    return false if applied_sla.sla_rt_due_at.blank?

    Time.current > applied_sla.sla_rt_due_at
  end

  def record_event(applied_sla, event_type)
    return if applied_sla.sla_events.exists?(event_type: event_type)

    applied_sla.sla_events.create!(
      conversation: conversation,
      account_id: conversation.account_id,
      sla_policy_id: applied_sla.sla_policy_id,
      inbox_id: conversation.inbox_id,
      event_type: event_type,
      meta: { due_at: applied_sla.public_send(:"sla_#{event_type}_due_at")&.iso8601 }
    )
  end
end
