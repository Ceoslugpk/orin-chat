class Sla::BreachService
  NOTIFICATION_TYPES = {
    frt: 'sla_missed_first_response',
    nrt: 'sla_missed_next_response',
    rt: 'sla_missed_resolution'
  }.freeze

  def initialize(applied_sla, event_type)
    @applied_sla = applied_sla
    @event_type = event_type
  end

  def perform
    return unless account.feature_enabled?('sla')
    return unless applied_sla.active? || applied_sla.active_with_misses?
    return unless breached?
    return unless record_event

    notify_agents
  end

  private

  attr_reader :applied_sla, :event_type

  delegate :account, :conversation, to: :applied_sla

  def due_at
    @due_at ||= applied_sla.public_send(:"sla_#{event_type}_due_at")
  end

  def breached?
    return false if due_at.blank? || Time.current < due_at

    breached_for_type?
  end

  def breached_for_type?
    case event_type
    when :frt
      first_response_pending?
    when :nrt
      next_response_pending?
    when :rt
      !conversation.resolved?
    else
      false
    end
  end

  def first_response_pending?
    conversation.first_reply_created_at.blank? || conversation.first_reply_created_at > due_at
  end

  def next_response_pending?
    conversation.waiting_since.present? && conversation.waiting_since <= due_at
  end

  def record_event
    return false if event_recorded?

    applied_sla.sla_events.create!(
      conversation: conversation,
      account_id: account.id,
      sla_policy_id: applied_sla.sla_policy_id,
      inbox_id: conversation.inbox_id,
      event_type: event_type,
      created_at: due_at,
      meta: event_meta
    )
    true
  end

  def event_recorded?
    return applied_sla.sla_events.exists?(event_type: event_type) unless event_type == :nrt

    applied_sla.sla_events
               .where(event_type: :nrt)
               .exists?(["meta->>'due_at' = ?", due_at.iso8601])
  end

  def event_meta
    {
      due_at: due_at.iso8601,
      waiting_since: conversation.waiting_since&.iso8601
    }.compact
  end

  def notify_agents
    recipients.each do |user|
      NotificationBuilder.new(
        notification_type: NOTIFICATION_TYPES.fetch(event_type),
        user: user,
        account: account,
        primary_actor: conversation
      ).perform
    end
  end

  def recipients
    return [conversation.assignee] if conversation.assignee.present?

    conversation.inbox.members
  end
end
