class Edition < ApplicationRecord
  belongs_to :workspace
  has_many :deal_products, dependent: :restrict_with_error

  validates :name, presence: true,
    uniqueness: { scope: :workspace_id, case_sensitive: false }

  scope :ordered, -> { order(:name) }

  def display_name = name
end
