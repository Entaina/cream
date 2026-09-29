class LeadFormTemplate < ApplicationRecord
  KINDS = %w[form page booking].freeze
  PATH_FORMAT = /\Apublic\/(?:lead_forms|pages|bookings)(?:\/[a-z0-9_]+)+\z/
  ROOT_PREFIX = "public/lead_forms/".freeze
  PAGE_PREFIX = "public/pages/".freeze
  BOOKING_PREFIX = "public/bookings/".freeze
  PARTIALS_PREFIX = "public/lead_forms/partials/".freeze
  SYSTEM_VIEW_PATHS = %w[public/lead_forms/success public/lead_forms/privacy].freeze

  belongs_to :workspace

  validates :path, presence: true, format: {with: PATH_FORMAT}, uniqueness: {scope: :workspace_id}
  validates :body, presence: true
  validates :kind, inclusion: {in: KINDS}
  validates :page_slug, format: {with: /\A[a-z0-9_-]+\z/}, allow_blank: true
  validates :page_slug, uniqueness: {scope: :workspace_id}, allow_nil: true
  validate :body_must_have_valid_liquid_syntax
  validate :page_slug_required_for_pages

  scope :ordered, -> { order(:path, :id) }
  scope :partials, -> { where(partial: true) }
  scope :views, -> { where(partial: false) }
  scope :form_pages, -> { views.where(kind: "form").where.not(path: SYSTEM_VIEW_PATHS) }
  scope :landing_pages, -> { views.where(kind: "page") }
  scope :booking_pages, -> { views.where(kind: "booking") }

  def self.form_page_path_for(template_key)
    "#{ROOT_PREFIX}#{template_key}"
  end

  def self.page_path_for(slug)
    "#{PAGE_PREFIX}#{slug}"
  end

  def self.template_key_for(path)
    return unless path.to_s.start_with?(ROOT_PREFIX)
    return if path.start_with?(PARTIALS_PREFIX)
    return if SYSTEM_VIEW_PATHS.include?(path)

    path.delete_prefix(ROOT_PREFIX).presence
  end

  def template_key
    self.class.template_key_for(path)
  end

  def display_name
    if partial? || path.to_s.start_with?(PARTIALS_PREFIX)
      path.to_s.delete_prefix(PARTIALS_PREFIX)
    elsif page?
      page_slug.presence || path.to_s.delete_prefix(PAGE_PREFIX)
    elsif booking?
      path.to_s.delete_prefix(BOOKING_PREFIX)
    else
      path.to_s.delete_prefix(ROOT_PREFIX)
    end
  end

  def slug
    @slug.presence || (page? ? page_slug : display_name)
  end

  def slug=(value)
    @slug = value.to_s.strip.presence
  end

  def page?
    kind == "page"
  end

  def booking?
    kind == "booking"
  end

  before_validation :assign_path_from_slug
  before_validation :normalize_non_form_kind
  after_save :refresh_submission_schema!, if: :form_page?

  def form_page?
    kind == "form" && !partial? && template_key.present?
  end

  def previewable?
    !partial?
  end

  def refresh_submission_schema!
    compiled = LeadFormTemplates::SchemaCompiler.compile(template: self)
    update_column(:submission_schema, compiled)
  end

  private

  def assign_path_from_slug
    segment = (@slug.presence || page_slug.presence || display_name.presence).to_s.strip.downcase
    if segment.blank?
      errors.add(:slug, :blank) unless path.present?
      return
    end

    unless segment.match?(/\A[a-z][a-z0-9_-]*\z/)
      errors.add(:slug, :invalid_format)
      return
    end

    if partial?
      self.path = "#{PARTIALS_PREFIX}#{segment.tr("-", "_")}"
    elsif page?
      normalized = segment.tr("_", "-")
      self.page_slug = normalized
      self.path = "#{PAGE_PREFIX}#{normalized.tr("-", "_")}"
    elsif booking?
      self.path = "#{BOOKING_PREFIX}#{segment.tr("-", "_")}"
    else
      self.path = "#{ROOT_PREFIX}#{segment.tr("-", "_")}"
    end
  end

  def page_slug_required_for_pages
    return unless page?

    errors.add(:page_slug, :blank) if page_slug.blank?
  end

  def normalize_non_form_kind
    self.partial = false if page? || booking?
  end

  def body_must_have_valid_liquid_syntax
    return if body.blank?

    environment = LeadFormTemplates::Renderer.build_environment
    Liquid::Template.parse(body, environment: environment)
  rescue Liquid::SyntaxError => e
    errors.add(:body, :reference_syntax_error, message: e.message)
  end
end
