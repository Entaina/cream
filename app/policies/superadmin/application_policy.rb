module Superadmin
  class ApplicationPolicy
    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    def index? = superadmin?
    def show? = superadmin?
    def create? = superadmin?
    def new? = create?
    def update? = superadmin?
    def edit? = update?
    def destroy? = superadmin?
    def enter? = superadmin?

    private

    def superadmin?
      user&.superadmin?
    end

    class Scope
      attr_reader :user, :scope

      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        return scope.none unless user&.superadmin?

        scope.all
      end
    end
  end
end
