class DealAccess < ApplicationRecord
  belongs_to :deal
  belongs_to :user

  validates :user_id, uniqueness: {scope: :deal_id}
  validate :user_belongs_to_deal_workspace

  private

  def user_belongs_to_deal_workspace
    return if deal.blank? || user.blank?
    return if deal.workspace.users.exists?(id: user_id)

    errors.add(:user, "must belong to the deal workspace")
  end
end
