# A product line on a deal. Unit price is copied from the catalogue on creation
# and can then be edited per line. The deal value is the sum of its line subtotals.
class DealProduct < ApplicationRecord
  belongs_to :deal
  belongs_to :product
  belongs_to :edition, optional: true

  # Set from the form: an edition is picked by name from the workspace catalogue
  # and created on the fly when it doesn't exist yet.
  attr_accessor :edition_name

  validates :quantity, numericality: {only_integer: true, greater_than: 0}
  validates :unit_price, numericality: {greater_than_or_equal_to: 0}
  validate :edition_belongs_to_product

  # On creation the unit price is taken from the catalogue, unless one was
  # explicitly provided; it can be edited afterwards (see DealProductsController#update).
  before_validation :copy_price_from_product, on: :create
  before_validation :resolve_edition
  after_save :sync_deal_value
  after_destroy :sync_deal_value
  after_create :track_product_added
  after_update :track_product_updated
  after_destroy :track_product_removed

  def subtotal = quantity * unit_price

  private

  def copy_price_from_product
    self.unit_price = product.price if product && !unit_price_changed?
  end

  # Resolve the typed edition name to a workspace edition, creating it if new.
  # A blank name clears the association.
  def resolve_edition
    return if edition_name.nil?
    return unless product

    name = edition_name.strip
    self.edition = name.blank? ? nil : product.editions.find_or_create_by(name: name)
  end

  def edition_belongs_to_product
    return if edition.nil? || product.nil?
    return if edition.product_id == product_id

    errors.add(:edition, "must belong to the same product")
  end

  def sync_deal_value
    deal.recalculate_value!
  end

  def track_product_added
    deal.track_activity("products_changed", metadata: product_metadata("added"))
  end

  def track_product_updated
    changes = saved_changes.except("updated_at", "created_at")
    return if changes.empty?

    deal.track_activity("products_changed", metadata: product_metadata("updated", changes: changes))
  end

  def track_product_removed
    return if destroyed_by_association

    deal.track_activity("products_changed", metadata: product_metadata("removed"))
  end

  def product_metadata(change, changes: nil)
    meta = {
      change: change,
      product: product.name,
      product_id: product_id,
      quantity: quantity,
      unit_price: unit_price.to_s
    }
    meta[:changes] = changes.transform_values { |(from, to)| [from.to_s, to.to_s] } if changes
    meta
  end
end
