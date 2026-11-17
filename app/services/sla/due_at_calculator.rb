class Sla::DueAtCalculator
  def initialize(policy:, inbox:)
    @policy = policy
    @inbox = inbox
  end

  def add(threshold, from: Time.current)
    return if threshold.blank?
    return from + threshold.seconds unless policy.only_during_business_hours
    return from + threshold.seconds unless inbox.working_hours_enabled?

    WorkingHours::Config.with_config(working_hours: working_hours, time_zone: inbox.timezone) do
      WorkingHours.add_seconds(from.in_time_zone(inbox.timezone), threshold)
    end
  end

  private

  attr_reader :policy, :inbox

  def working_hours
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
