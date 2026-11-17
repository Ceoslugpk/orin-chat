class AuditLogPolicy < ApplicationPolicy
  def show?
    @account_user.administrator?
  end

  def download?
    show?
  end
end
