module Marketing
  class ProductInterestPolicy < WorkspaceRecordPolicy
    def create? = update_person?
    def dismiss? = update_person?
    def convert? = update_person? && DealPolicy.new(context, Deal.new(workspace: workspace, company: record.person.company)).create?

    class Scope < Scope
      def resolve
        scope.where(workspace: workspace)
      end
    end

    private

    def update_person?
      person = record.is_a?(ProductInterest) ? record.person : record
      PersonPolicy.new(context, person).update?
    end
  end
end
