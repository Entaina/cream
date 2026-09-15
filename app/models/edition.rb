class Edition < ApplicationRecord
  belongs_to :workspace
  belongs_to :product
  has_many :deal_products, dependent: :restrict_with_error

  before_validation :set_workspace_from_product, on: :create

  validates :name, presence: true,
    uniqueness: {scope: :product_id, case_sensitive: false}

  before_validation :strip_name
  validate :ends_on_not_before_starts_on

  scope :ordered, -> { order(:name) }
  scope :not_started, -> { where.not(starts_on: nil).where("starts_on > ?", Date.current) }
  scope :search, ->(q) {
    where("editions.name ILIKE :q", q: "%#{sanitize_sql_like(q)}%") if q.present?
  }

  def display_name = name

  def date_range_label
    if starts_on && ends_on
      "#{I18n.l(starts_on, format: :short)} – #{I18n.l(ends_on, format: :short)}"
    elsif starts_on
      I18n.t("editions.from", date: I18n.l(starts_on, format: :short))
    elsif ends_on
      I18n.t("editions.until", date: I18n.l(ends_on, format: :short))
    end
  end

  private

  def set_workspace_from_product
    self.workspace = product.workspace if product.present?
  end

  def strip_name
    self.name = name.strip if name.present?
  end

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, "must be on or after the start date")
  end
end
