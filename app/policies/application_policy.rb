class ApplicationPolicy
  attr_reader :user_context, :user, :record, :account, :account_user

  def initialize(user_context, record)
    @user_context = user_context
    @user = user_context[:user]
    @account = user_context[:account]
    @account_user = user_context[:account_user]
    @record = record
  end

  def administrator?
    account_user&.administrator? || false
  end

  def restricted_custom_role?
    account_user&.uses_custom_role_permissions? || false
  end

  def custom_role_permission?(permission)
    restricted_custom_role? && account_user.permissions.include?(permission)
  end

  def index?
    false
  end

  def show?
    scope.exists?(id: record.id)
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(user_context, record.class)
  end

  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      scope
    end
  end
end
