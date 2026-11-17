class Sla::ApplyPolicyService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    return unless conversation.account.feature_enabled?('sla')
    return if conversation.sla_policy_id.blank?

    policy = conversation.sla_policy
    return unless policy

    applied_sla = conversation.applied_slas.find_or_initialize_by(
      account_id: conversation.account_id,
      sla_policy_id: policy.id
    )
    return applied_sla if applied_sla.persisted?

    applied_sla.assign_attributes(
      sla_status: :active,
      sla_frt_due_at: due_at(policy, policy.first_response_time_threshold),
      sla_nrt_due_at: due_at(policy, policy.next_response_time_threshold),
      sla_rt_due_at: due_at(policy, policy.resolution_time_threshold)
    )
    applied_sla.save!
    applied_sla
  end

  private

  attr_reader :conversation

  def applied_at
    @applied_at ||= Time.current
  end

  def due_at(policy, threshold)
    return if threshold.blank?
    return applied_at + threshold.seconds unless policy.only_during_business_hours

    inbox = conversation.inbox
    return applied_at + threshold.seconds unless inbox.working_hours_enabled?

    WorkingHours::Config.with_config(working_hours: working_hours(inbox), time_zone: inbox.timezone) do
      WorkingHours.add_seconds(applied_at.in_time_zone(inbox.timezone), threshold)
    end
  end

  def working_hours(inbox)
    inbox.working_hours.each_with_object({}) do |working_hour, config|
      next if working_hour.closed_all_day?

      config[week_day(working_hour.day_of_week)] = {
        format_time(working_hour.open_hour, working_hour.open_minutes) =>
          format_time(working_hour.close_hour, working_hour.close_minutes)
      }
    end
  end

  def week_day(day_of_week)
    %i[sun mon tue wed thu fri sat][day_of_week]
  end

  def format_time(hour, minute)
    format('%<hour>02d:%<minute>02d', hour: hour, minute: minute)
  end
end
