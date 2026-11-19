class Sla::ReopenPolicyService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    return unless conversation.account.feature_enabled?('sla')

    applied_sla = conversation.applied_slas.find_by(sla_policy_id: conversation.sla_policy_id)
    return if applied_sla&.completed_at.blank?

    applied_sla.update!(
      sla_status: applied_sla.sla_events.exists? ? :active_with_misses : :active,
      completed_at: nil
    )
  end

  private

  attr_reader :conversation
end
