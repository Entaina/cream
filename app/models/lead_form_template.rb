class LeadFormTemplate < ApplicationRecord
  PATH_FORMAT = /\Apublic\/lead_forms(?:\/[a-z0-9_]+)+\z/
  ROOT_PREFIX = "public/lead_forms/".freeze
  PARTIALS_PREFIX = "public/lead_forms/partials/".freeze
  SYSTEM_VIEW_PATHS = %w[public/lead_forms/success].freeze

  belongs_to :workspace

  validates :path, presence: true, format: { with: PATH_FORMAT }, uniqueness: { scope: :workspace_id }
  validates :body, presence: true
  validate :body_must_have_valid_liquid_syntax

  scope :ordered, -> { order(:path, :id) }
  scope :partials, -> { where(partial: true) }
  scope :views, -> { where(partial: false) }
  scope :form_pages, -> { views.where.not(path: SYSTEM_VIEW_PATHS) }

  def self.form_page_path_for(template_key)
    "#{ROOT_PREFIX}#{template_key}"
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
    else
      path.to_s.delete_prefix(ROOT_PREFIX)
    end
  end

  def slug
    @slug.presence || display_name
  end

  def slug=(value)
    @slug = value.to_s.strip.presence
  end

  before_validation :assign_path_from_slug
  after_save :refresh_submission_schema!, if: :form_page?

  def form_page?
    !partial? && template_key.present?
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
    segment = (@slug.presence || display_name.presence).to_s.strip.downcase
    if segment.blank?
      errors.add(:slug, "can't be blank") unless path.present?
      return
    end

    unless segment.match?(/\A[a-z][a-z0-9_]*\z/)
      errors.add(:slug, "solo letras minúsculas, números y guiones bajos")
      return
    end

    self.path = partial? ? "#{PARTIALS_PREFIX}#{segment}" : "#{ROOT_PREFIX}#{segment}"
  end

  def body_must_have_valid_liquid_syntax
    return if body.blank?

    environment = LeadFormTemplates::Renderer.build_environment
    Liquid::Template.parse(body, environment: environment)
  rescue Liquid::SyntaxError => e
    errors.add(:body, "syntax error: #{e.message}")
  end
end
