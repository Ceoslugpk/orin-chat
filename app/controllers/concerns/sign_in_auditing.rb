# Records sign-ins and sign-outs in the audit log of every account the user
# belongs to. Impersonated sessions are not recorded as the user's own.
module SignInAuditing
  def destroy
    impersonating = impersonation_token_entry.present?
    super do |user|
      record_session_audit(user, 'sign_out') unless impersonating
      yield user if block_given?
    end
  end

  private

  def record_session_audit(user, action)
    user.accounts.find_each do |account|
      AuditLog.record!(auditable: user, account: account, action: action, user: user)
    end
  end
end
