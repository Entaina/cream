# One numbered revision of an Offer: an uploaded PDF/HTML/ZIP file, or HTML pasted
# into `html_body` (plain document, not a template).
class OfferVersion < ApplicationRecord
  FILE_CONTENT_TYPES = %w[
    application/pdf text/html application/zip application/x-zip-compressed
  ].freeze
  ZIP_CONTENT_TYPES = %w[application/zip application/x-zip-compressed].freeze
  PACKAGE_TOKEN_EXPIRY = 12.hours

  belongs_to :offer
  belongs_to :user

  has_one_attached :file

  before_validation :assign_number, on: :create
  before_validation :detect_zip_entry_path

  validate :single_content_source
  validate :file_type_allowed
  validate :zip_entry_path_present

  scope :newest_first, -> { order(number: :desc) }

  def pdf?
    pending_file_content_type == "application/pdf"
  end

  def zip?
    pending_file_content_type.in?(ZIP_CONTENT_TYPES)
  end

  def html?
    !pdf? && !zip?
  end

  # Raw HTML to preview: the pasted body, or the contents of an uploaded HTML file.
  def html_content
    return html_body.to_s unless file.attached?
    return "" if zip?

    file.download.force_encoding(Encoding::UTF_8).scrub
  end

  def package_token
    signed_id(purpose: :offer_package, expires_in: PACKAGE_TOKEN_EXPIRY)
  end

  private

  def assign_number
    self.number ||= (offer.versions.maximum(:number) || 0) + 1
  end

  def single_content_source
    has_file = file.attached? || attachment_changes["file"].present?
    has_html = html_body.present?
    errors.add(:base, :offer_content_required) if !has_file && !has_html
    errors.add(:base, :offer_single_source) if has_file && has_html
  end

  def file_type_allowed
    return unless file.attached? || attachment_changes["file"].present?
    return if pending_file_content_type.in?(FILE_CONTENT_TYPES)

    errors.add(:file, :offer_file_type)
  end

  def detect_zip_entry_path
    return unless zip_file_being_attached?

    self.entry_path = nil
    io = io_from_attachment_change
    return unless io

    result = OfferPackage.detect_entry(io)
    io.rewind if io.respond_to?(:rewind)
    case result
    when OfferPackage::Entry
      self.entry_path = result.entry_path
    when OfferPackage::Failure
      errors.add(:file, result.error_key)
    end
  end

  def zip_entry_path_present
    return unless zip?
    return if entry_path.present?

    errors.add(:file, :offer_zip_entry_not_found) unless errors.added?(:file, :offer_zip_entry_not_found)
  end

  def zip_file_being_attached?
    pending_file_content_type.in?(ZIP_CONTENT_TYPES)
  end

  def pending_file_content_type
    if attachment_changes["file"].present?
      content_type_from_change(attachment_changes["file"])
    elsif file.attached?
      file.content_type
    end
  end

  def io_from_attachment_change
    change = attachment_changes["file"]
    return unless change

    attachable = change.attachable
    case attachable
    when ActionDispatch::Http::UploadedFile
      attachable.tempfile.tap(&:rewind)
    when Hash
      io = attachable[:io]
      io.rewind if io.respond_to?(:rewind)
      io
    end
  end

  def content_type_from_change(change)
    attachable = change.attachable
    case attachable
    when ActionDispatch::Http::UploadedFile
      attachable.content_type
    when Hash
      attachable[:content_type]
    end
  end
end
