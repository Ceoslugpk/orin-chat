# Configuration for the audited gem: https://github.com/collectiveidea/audited
#
# Every audit is stored as an AuditLog and associated with its account, so
# Settings → Audit Logs can list an account's activity. This is the single
# place that declares which models are audited and which attributes are
# recorded; keep it in sync with the events the dashboard can display
# (app/javascript/dashboard/helper/auditlogHelper.js).
Audited.config do |config|
  config.audit_class = 'AuditLog'
end

Rails.application.config.to_prepare do
  Account.audited on: [:update], except: %i[internal_attributes]

  Inbox.audited associated_with: :account
  Webhook.audited associated_with: :account, except: %i[secret]
  AutomationRule.audited associated_with: :account
  Macro.audited associated_with: :account
  Team.audited associated_with: :account
  CustomRole.audited associated_with: :account

  # Only membership and permission fields: active_at changes on every request.
  AccountUser.audited associated_with: :account,
                      only: %i[user_id role availability auto_offline custom_role_id agent_capacity_policy_id]

  InboxMember.audited associated_with: :account, on: %i[create destroy]
  TeamMember.audited associated_with: :account, on: %i[create destroy]
end
