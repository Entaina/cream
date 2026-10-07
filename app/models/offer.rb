# A commercial offer attached to a deal. It is a plain document, not a
# template: either an uploaded PDF/HTML file or HTML pasted into `html_body`.
class Offer < ApplicationRecord
  FILE_CONTENT_TYPES = %w[application/pdf text/html].freeze

  belongs_to :workspace
  belongs_to :deal
  belongs_to :user

  has_one_attached :file

  before_validation :default_name_from_file

  validates :name, presence: true
  validate :single_content_source
  validate :file_type_allowed
  validate :deal_in_workspace

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

  def default_name_from_file
    self.name = file.filename.base if name.blank? && file.attached?
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

  def deal_in_workspace
    return if deal.nil? || deal.workspace_id == workspace_id

    errors.add(:deal, :must_belong_to_same_workspace)
  end
end
