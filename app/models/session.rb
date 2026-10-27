class Session < ApplicationRecord
  LIFETIME = 30.days
  RENEWAL_INTERVAL = 1.hour

  belongs_to :user
  has_many :list_filter_states, dependent: :delete_all

  scope :active, -> { where("expires_at > ?", Time.current) }

  before_create :set_initial_expiry

  def touch_activity!
    return if expires_at.present? && expires_at > (LIFETIME - RENEWAL_INTERVAL).from_now

    update_column(:expires_at, LIFETIME.from_now)
  end

  private

  def set_initial_expiry
    self.expires_at ||= LIFETIME.from_now
  end
end
