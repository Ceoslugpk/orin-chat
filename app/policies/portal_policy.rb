class PortalPolicy < ApplicationPolicy
  def index?
    @account.users.include?(@user)
  end

  def update?
    knowledge_base_manage?
  end

  def show?
    @account.users.include?(@user)
  end

  def edit?
    knowledge_base_manage?
  end

  def create?
    knowledge_base_manage?
  end

  def destroy?
    knowledge_base_manage?
  end

  def logo?
    knowledge_base_manage?
  end

  def remove_locale?
    knowledge_base_manage?
  end

  def send_instructions?
    knowledge_base_manage?
  end

  def ssl_status?
    @account.users.include?(@user)
  end

  private

  def knowledge_base_manage?
    administrator? || custom_role_permission?('knowledge_base_manage')
  end
end

PortalPolicy.prepend_mod_with('PortalPolicy')
