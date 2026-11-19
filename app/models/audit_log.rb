# Account activity trail shown in Settings → Audit Logs.
#
# Rows are written automatically for the models registered in
# config/initializers/audited.rb, and explicitly (via .record!) for events
# that are not plain create/update/destroy callbacks: sign-ins, message
# deletions and conversation deletions.
class AuditLog < Audited::Audit
  PER_PAGE = 25

  # Account changes are audited on the account itself; everything else is
  # associated with the account it belongs to.
  scope :for_account, lambda { |account|
    where(associated_type: 'Account', associated_id: account.id)
      .or(where(auditable_type: 'Account', auditable_id: account.id))
  }

  def self.record!(auditable:, account:, action:, changes: {}, user: nil)
    create!(auditable: auditable, associated: account, action: action, audited_changes: changes, user: user)
  end

  # Attributes the request context (user, IP) to audits written outside a
  # controller, such as in background jobs.
  def self.with_context(user:, ip:, &)
    previous_ip = Audited.store[:current_remote_address]
    Audited.store[:current_remote_address] = ip
    Audited.audit_class.as_user(user, &)
  ensure
    Audited.store[:current_remote_address] = previous_ip
  end

  def location
    [city, country].compact_blank.join(', ').presence
  end
end
