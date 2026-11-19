class Sla::ApplyPolicyService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    return unless conversation.account.feature_enabled?('sla')
    return if conversation.sla_policy_id.blank?

    policy = conversation.sla_policy
    return unless policy

    applied_sla = find_or_initialize(policy)
    return applied_sla if applied_sla.persisted?

    applied_sla.assign_attributes(due_attributes(policy))
    applied_sla.save!
    Sla::ScheduleBreachChecksService.new(applied_sla).perform
    complete_if_resolved
    applied_sla
  end

  private

  attr_reader :conversation

  def find_or_initialize(policy)
    conversation.applied_slas.find_or_initialize_by(
      account_id: conversation.account_id,
      sla_policy_id: policy.id
    )
  end

  def due_attributes(policy)
    calculator = Sla::DueAtCalculator.new(policy: policy, inbox: conversation.inbox)
    {
      sla_status: :active,
      sla_frt_due_at: calculator.add(policy.first_response_time_threshold),
      sla_nrt_due_at: next_response_due_at(policy, calculator),
      sla_rt_due_at: calculator.add(policy.resolution_time_threshold)
    }
  end

  def next_response_due_at(policy, calculator)
    return if conversation.first_reply_created_at.blank? || conversation.waiting_since.blank?

    calculator.add(policy.next_response_time_threshold, from: conversation.waiting_since)
  end

  def complete_if_resolved
    Sla::CompletePolicyService.new(conversation).perform if conversation.resolved?
  end
end
