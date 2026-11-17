require 'rails_helper'

RSpec.describe AuditLog::RetentionJob do
  let(:account) { create(:account) }

  def create_audit_log
    AuditLog.record!(auditable: account, account: account, action: 'update', changes: { 'name' => %w[old new] })
  end

  it 'keeps logs indefinitely when no retention period is configured' do
    old_log = create_audit_log
    old_log.update_column(:created_at, 10.years.ago) # rubocop:disable Rails/SkipsModelValidations

    expect { described_class.perform_now }.not_to change(AuditLog, :count)
  end

  it 'deletes logs older than the configured retention period' do
    old_log = create_audit_log
    old_log.update_column(:created_at, 31.days.ago) # rubocop:disable Rails/SkipsModelValidations
    recent_log = create_audit_log
    InstallationConfig.find_or_initialize_by(name: 'AUDIT_LOG_RETENTION_DAYS').update!(value: '30')

    described_class.perform_now

    expect(AuditLog.exists?(old_log.id)).to be(false)
    expect(AuditLog.exists?(recent_log.id)).to be(true)
  end

  it 'ignores non-positive retention values' do
    old_log = create_audit_log
    old_log.update_column(:created_at, 31.days.ago) # rubocop:disable Rails/SkipsModelValidations
    InstallationConfig.find_or_initialize_by(name: 'AUDIT_LOG_RETENTION_DAYS').update!(value: '0')

    expect { described_class.perform_now }.not_to change(AuditLog, :count)
  end
end
