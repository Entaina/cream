class BeehiivConnection < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  has_many :beehiiv_publications, dependent: :destroy

  validates :workspace_id, uniqueness: true
  validates :api_key, presence: true

  def connected? = api_key.present? && beehiiv_publications.any?

  def masked_api_key
    mask(api_key)
  end

  private

  def mask(value)
    return "" if value.blank?
    return "…" if value.length < 8

    "#{value.first(4)}…#{value.last(4)}"
  end
end
