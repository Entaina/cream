class List < ApplicationRecord
  RECORD_TYPES = %w[Person Company Deal].freeze
  COLORS = %w[hoki copperfield golden green red chicago].freeze

  belongs_to :workspace
  has_many :list_entries, -> { order(:position, :id) }, dependent: :destroy

  validates :name, presence: true
  validates :record_type, inclusion: {in: RECORD_TYPES}
  validates :color, inclusion: {in: COLORS}

  attribute :color, default: "hoki"

  def records
    list_entries.includes(:record).map(&:record)
  end
end
