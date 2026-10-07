# One numbered revision of an Offer: an uploaded PDF/HTML file, or HTML pasted
# into `html_body` (plain document, not a template).
class OfferVersion < ApplicationRecord
  FILE_CONTENT_TYPES = %w[application/pdf text/html].freeze

  belongs_to :offer
  belongs_to :user

  has_one_attached :file

  before_validation :assign_number, on: :create

  validate :single_content_source
  validate :file_type_allowed

  scope :newest_first, -> { order(number: :desc) }

  def pdf?
    file.attached? && file.content_type == "application/pdf"
  end

  def html?
    !pdf?
  end

  # Raw HTML to preview: the pasted body, or the contents of an uploaded HTML file.
  def html_content
    return html_body.to_s unless file.attached?

    file.download.force_encoding(Encoding::UTF_8).scrub
  end

  private

  def assign_number
    self.number ||= (offer.versions.maximum(:number) || 0) + 1
  end

  def single_content_source
    has_file = file.attached?
    has_html = html_body.present?
    errors.add(:base, :offer_content_required) if !has_file && !has_html
    errors.add(:base, :offer_single_source) if has_file && has_html
  end

  def file_type_allowed
    return unless file.attached?
    return if FILE_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, :offer_file_type)
  end
end
