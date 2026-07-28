class StripeConnection < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  has_many :stripe_payments, dependent: :destroy

  validates :workspace_id, uniqueness: true
  validates :api_key, format: { with: /\A(sk|rk)_[A-Za-z0-9_]+\z/, message: "must be a Stripe secret or restricted key (sk_… / rk_…)" },
    allow_blank: true

  def connected? = api_key.present?

  # Show only the tail so the key is identifiable without ever echoing it back.
  def masked_api_key
    return "" if api_key.blank?

    "#{api_key.first(7)}…#{api_key.last(4)}"
  end
end
