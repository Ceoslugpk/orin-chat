class AuditLog::RetentionJob < ApplicationJob
  queue_as :purgable

  def perform
    retention_days = InstallationConfig.find_by(name: 'AUDIT_LOG_RETENTION_DAYS')&.value.to_i
    return unless retention_days.positive?

    AuditLog.where('created_at < ?', retention_days.days.ago).delete_all
  end
end
