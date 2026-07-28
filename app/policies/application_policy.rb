class ApplicationPolicy
  attr_reader :context, :user, :workspace, :record

  def initialize(context, record)
    @context = context
    @user = context.user
    @workspace = context.workspace
    @record = record
  end

  def member?
    context.member?
  end

  def admin?
    context.admin?
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  def in_workspace?
    member? && record.workspace_id == workspace.id
  end

  class Scope
    attr_reader :context, :user, :workspace, :scope

    def initialize(context, scope)
      @context = context
      @user = context.user
      @workspace = context.workspace
      @scope = scope
    end

    def resolve
      scope.none
    end

    def member?
      context.member?
    end
  end
end
