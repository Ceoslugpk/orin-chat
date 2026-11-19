class ArticlePolicy < ApplicationPolicy
  def index?
    @account.users.include?(@user)
  end

  def update?
    knowledge_base_manage?
  end

  def show?
    knowledge_base_manage?
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

  def reorder?
    knowledge_base_manage?
  end

  def preview_token?
    show?
  end

  private

  def knowledge_base_manage?
    administrator? || custom_role_permission?('knowledge_base_manage')
  end
end

ArticlePolicy.prepend_mod_with('ArticlePolicy')
