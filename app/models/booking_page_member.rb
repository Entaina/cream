class BookingPageMember < ApplicationRecord
  belongs_to :booking_page
  belongs_to :user

  validates :user_id, uniqueness: {scope: :booking_page_id}
  validate :user_belongs_to_workspace
  validate :user_is_not_host

  def calendar_connection
    booking_page.workspace.calendar_connections.find_by(user: user)
  end

  private

  def user_belongs_to_workspace
    return if booking_page.nil? || user.nil?

    errors.add(:user, :must_be_workspace_member) unless booking_page.workspace.users.exists?(id: user_id)
  end

  def user_is_not_host
    return if booking_page.nil? || user.nil?

    errors.add(:user, :cannot_be_host) if booking_page.host_id == user_id
  end
end
