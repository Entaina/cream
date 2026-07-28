class Product < ApplicationRecord
  SEGMENTS = %w[b2b b2c].freeze
  SEGMENT_LABELS = { "b2b" => "B2B", "b2c" => "B2C" }.freeze

  belongs_to :workspace
  has_many :deal_products, dependent: :restrict_with_error

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :segment, inclusion: { in: SEGMENTS }, allow_blank: true

  scope :search, ->(q) {
    where("products.name ILIKE :q OR products.description ILIKE :q", q: "%#{sanitize_sql_like(q)}%") if q.present?
  }
  scope :with_segment, ->(segment) { where(segment: segment) if segment.present? && SEGMENTS.include?(segment) }
  scope :ordered, -> { order(:name) }

  def display_name = name

  def segment_label
    SEGMENT_LABELS[segment]
  end
end
