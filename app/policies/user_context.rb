class UserContext
  attr_reader :user, :workspace

  def initialize(user:, workspace:)
    @user = user
    @workspace = workspace
  end

  def membership
    return @membership if defined?(@membership)

    @membership = Membership.find_by(user: user, workspace: workspace) if user && workspace
  end

  def member?
    membership.present?
  end

  def admin?
    membership&.role == "admin"
  end

  def sales_director?
    membership&.role == "sales_director"
  end

  def salesperson?
    membership&.role == "salesperson"
  end

  def ai_salesperson?
    membership&.role == "ai_salesperson"
  end

  def can_view_others_tasks?
    admin? || sales_director? ||
      workspace&.salespeople_can_view_all_deals? ||
      workspace&.salespeople_can_edit_all_deals?
  end
end
