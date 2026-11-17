class ReportPolicy < ApplicationPolicy
  def view?
    administrator? || custom_role_permission?('report_manage')
  end
end

ReportPolicy.prepend_mod_with('ReportPolicy')
