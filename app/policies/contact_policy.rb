class ContactPolicy < ApplicationPolicy
  def index?
    contact_access?
  end

  def active?
    contact_access?
  end

  def search?
    contact_access?
  end

  def filter?
    contact_access?
  end

  def show?
    contact_access?
  end

  def contactable_inboxes?
    contact_access?
  end

  def create?
    contact_access?
  end

  def update?
    contact_access?
  end

  def avatar?
    contact_access?
  end

  def destroy_custom_attributes?
    contact_access?
  end

  def import?
    contact_admin_action?
  end

  def export?
    contact_admin_action?
  end

  def destroy?
    contact_admin_action?
  end

  private

  def contact_access?
    account_user.nil? || account_user.contact_access?
  end

  def contact_admin_action?
    administrator? || custom_role_permission?('contact_manage')
  end
end

ContactPolicy.prepend_mod_with('ContactPolicy')
