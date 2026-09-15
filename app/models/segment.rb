class Segment < ApplicationRecord
  RECORD_TYPES = SavedView::RECORD_TYPES

  belongs_to :workspace
  belongs_to :user

  has_many :segment_memberships, dependent: :destroy

  validates :name, :record_type, presence: true
  validates :record_type, inclusion: {in: RECORD_TYPES}

  scope :ordered, -> { order(:name, :id) }
  scope :visible_to, ->(user) { where(user: user).or(where(shared: true)) }

  before_validation :normalize_filters

  def resolve(scope = nil)
    base = scope || workspace.public_send(record_type.tableize)
    Marketing::FilterResolver.new(workspace: workspace, record_type: record_type, filters: filters).resolve(base)
  end

  private

  def normalize_filters
    return unless filters.is_a?(String)

    self.filters = JSON.parse(filters)
  rescue JSON::ParserError
    errors.add(:filters, "must be valid JSON")
  end
end
