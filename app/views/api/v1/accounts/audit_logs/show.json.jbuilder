json.audit_logs @audit_logs do |audit_log|
  json.id audit_log.id
  json.auditable_id audit_log.auditable_id
  json.auditable_type audit_log.auditable_type
  json.auditable audit_log.auditable_type == 'AccountUser' ? audit_log.auditable&.slice(:id, :user_id, :role) : nil
  json.associated_id audit_log.associated_id
  json.associated_type audit_log.associated_type
  json.user_id audit_log.user_id
  json.user_type audit_log.user_type
  json.username audit_log.username
  json.action audit_log.action
  json.audited_changes audit_log.audited_changes
  json.version audit_log.version
  json.comment audit_log.comment
  json.request_uuid audit_log.request_uuid
  json.remote_address audit_log.remote_address
  json.location audit_log.location
  json.created_at audit_log.created_at.to_i
end
json.current_page @current_page
json.per_page AuditLog::PER_PAGE
json.total_entries @total_entries
