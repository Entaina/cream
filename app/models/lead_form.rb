class LeadForm < ApplicationRecord
  PLACEHOLDER_COMPANY_NAME = "Particulares".freeze
  HONEYPOT_FIELD = "_honeypot".freeze
  TIMESTAMP_FIELD = "_ts".freeze
  # Anti-spam: a human needs at least this long to fill the form.
  MIN_SECONDS_TO_SUBMIT = 3
  # Containment caps: beyond these, submissions are silently discarded.
  MAX_SUBMISSIONS_PER_EMAIL_PER_DAY = 5
  MAX_SUBMISSIONS_PER_FORM_PER_HOUR = 100
  METADATA_FIELDS = %w[
    lead_form_slug lead_form_name source_page referrer
    utm_source utm_medium utm_campaign utm_term utm_content
  ].freeze
  SUBMISSION_FIELD_KEYS = %w[
    email first_name last_name phone phone_prefix how_heard help_type message
    product_id edition_id
    company_name company_cif employee_range qualifying_answer job_title audience tech_profile
    ia_work_task organization_ia_stage newsletter_opt_in
  ].freeze
  RESERVED_FIELD_KEYS = (
    SUBMISSION_FIELD_KEYS + METADATA_FIELDS + [ HONEYPOT_FIELD, TIMESTAMP_FIELD, "gdpr_consent" ]
  ).freeze
  HIDDEN_FIELD_KEY_FORMAT = /\A[a-z][a-z0-9_]{0,39}\z/
  HOW_HEARD_OPTIONS = [
    [ "Redes sociales", "redes_sociales" ],
    [ "Recomendación de alguien", "recomendacion" ],
    [ "Búsqueda en internet", "busqueda" ],
    [ "Evento o webinar", "evento" ],
    [ "Newsletter o email", "newsletter" ],
    [ "Otro", "otro" ]
  ].freeze
  CONTACTO_HELP_OPTIONS = [
    [ "Curso", "curso" ],
    [ "Entrenamiento", "entrenamiento" ],
    [ "Proyecto / consultoría", "proyecto_consultoria" ],
    [ "Otro", "otro" ]
  ].freeze
  CONTACTO_HELP_TYPE_KEYS = CONTACTO_HELP_OPTIONS.map(&:last).freeze
  LIDERANDO_IA_AUDIENCE_OPTIONS = [
    [ "Para mí", "para_mi" ],
    [ "Para mi equipo", "para_equipo" ]
  ].freeze
  DESARROLLANDO_IA_AUDIENCE_OPTIONS = [
    [ "Solo para mí", "para_mi" ],
    [ "Para mi equipo", "para_equipo" ],
    [ "Para mí y mi equipo", "para_mi_y_equipo" ]
  ].freeze
  LIDERANDO_IA_HOW_HEARD_OPTIONS = [
    [ "LinkedIn", "linkedin" ],
    [ "Newsletter", "newsletter" ],
    [ "Recomendación", "recomendacion" ],
    [ "Google", "google" ],
    [ "Evento", "evento" ],
    [ "Otro", "otro" ]
  ].freeze
  DESARROLLANDO_IA_TECH_PROFILE_OPTIONS = [
    [ "Desarrollo/programo a diario", "desarrollo" ],
    [ "Perfil técnico no-dev", "perfil_tecnico" ],
    [ "No técnico", "no_tecnico" ]
  ].freeze
  COMPANY_EMPLOYEE_RANGE_OPTIONS = Company::EMPLOYEE_RANGES.map { |range| [ "#{range} empleados", range ] }.freeze
  PHONE_PREFIX_OPTIONS = [
    [ "+34", "+34" ],
    [ "+351", "+351" ],
    [ "+33", "+33" ],
    [ "+39", "+39" ],
    [ "+44", "+44" ],
    [ "+49", "+49" ],
    [ "+1", "+1" ],
    [ "+52", "+52" ],
    [ "+54", "+54" ],
    [ "+56", "+56" ],
    [ "+57", "+57" ]
  ].freeze

  belongs_to :workspace
  belongs_to :pipeline
  belongs_to :pipeline_stage, optional: true
  belongs_to :product, optional: true
  belongs_to :responsible, class_name: "User"
  belongs_to :email_template, optional: true

  has_many :lead_submissions, dependent: :destroy

  validates :name, :slug, :template_key, :first_task_title, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :template_key, inclusion: { in: ->(form) { form.class.available_template_keys } }
  validates :first_task_due_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :success_redirect_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validate :associations_belong_to_workspace
  validate :pipeline_routes_belong_to_workspace
  validate :hidden_field_keys_are_valid

  before_validation :normalize_slug
  before_validation :normalize_success_redirect_url
  before_validation :normalize_hidden_field_keys
  before_validation :normalize_pipeline_routes

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  def contacto_template?
    template_key == "contacto"
  end

  def liderando_ia_template?
    template_key == "liderando_ia"
  end

  def liderando_ia_reserva_template?
    template_key == "liderando_ia_reserva"
  end

  def desarrollando_ia_reserva_template?
    template_key == "desarrollando_ia_reserva"
  end

  def reserva_template?
    liderando_ia_reserva_template? || desarrollando_ia_reserva_template?
  end

  def trabajando_ia_template?
    template_key == "trabajando_ia"
  end

  def desarrollando_ia_template?
    template_key == "desarrollando_ia"
  end

  def adoption_template?
    template_key == "adoption"
  end

  def indice_adopcion_ia_template?
    template_key == "indice_adopcion_ia"
  end

  def entrenadores_template?
    template_key == "entrenadores"
  end

  def first_task_due_on(on: Date.current)
    on + first_task_due_days.days
  end

  ADOPTION_STAGE_NAME = "Demo".freeze

  def requires_job_title?
    indice_adopcion_ia_template?
  end

  def render_base_fields?
    !reserva_template?
  end

  def show_how_heard_in_base?
    !contacto_template? && !liderando_ia_template? && !reserva_template? && !trabajando_ia_template? && !desarrollando_ia_template? && !adoption_template? && !indice_adopcion_ia_template? && !entrenadores_template?
  end

  def show_phone_in_base?
    !entrenadores_template?
  end

  def require_phone?
    show_phone_in_base?
  end

  def show_newsletter_opt_in?
    !reserva_template?
  end

  def entaina_privacy_consent?
    liderando_ia_template? || reserva_template? || entrenadores_template?
  end

  def configured_stage_for(for_pipeline)
    return if pipeline_stage.nil? || for_pipeline.nil?
    return unless pipeline_stage.pipeline_id == for_pipeline.id

    pipeline_stage
  end

  def resolve_stage(for_pipeline: pipeline)
    configured = configured_stage_for(for_pipeline)
    return configured if configured
    return for_pipeline.first_stage unless adoption_template?

    for_pipeline.pipeline_stages.find_by("name ILIKE ?", ADOPTION_STAGE_NAME) || for_pipeline.first_stage
  end

  def resolve_pipeline(help_type: nil)
    return pipeline unless contacto_template?

    route_id = pipeline_routes[help_type.to_s].presence
    return workspace.pipelines.find(route_id) if route_id.present?

    pipeline
  end

  def help_type_label(help_type)
    CONTACTO_HELP_OPTIONS.to_h.invert.fetch(help_type.to_s, help_type.to_s.humanize)
  end

  def resolved_product(product_id_param: nil)
    id = product_id_param.presence || product_id
    return if id.blank?

    workspace.products.find_by(id: id)
  end

  def open_editions_for(product)
    return Edition.none unless product

    product.editions.not_finished.order(Arel.sql("starts_on NULLS LAST"), :name)
  end

  def self.available_template_keys
    Dir.glob(Rails.root.join("app/views/public/lead_forms/templates/_*.html.erb")).map do |path|
      File.basename(path).delete_prefix("_").delete_suffix(".html.erb")
    end.sort
  end

  def self.placeholder_company_for(workspace)
    workspace.companies.find_or_create_by!(name: PLACEHOLDER_COMPANY_NAME)
  end

  # Signed render-time timestamp used as a time-trap against bots.
  def self.signed_timestamp(at: Time.current)
    timestamp_verifier.generate(at.to_i)
  end

  def self.submitted_after_min_time?(token)
    issued_at = timestamp_verifier.verify(token.to_s)
    Time.current.to_i - issued_at.to_i >= MIN_SECONDS_TO_SUBMIT
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    false
  end

  def self.timestamp_verifier
    Rails.application.message_verifier("lead_form_timestamp")
  end
  private_class_method :timestamp_verifier

  def success_redirect_location
    url = success_redirect_url.to_s.strip.presence
    return if url.blank?

    uri = URI.parse(url)
    return unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def hidden_field_keys_text
    hidden_field_keys.join("\n")
  end

  def hidden_field_keys_text=(value)
    self.hidden_field_keys = value.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
  end

  def public_url
    Rails.application.routes.url_helpers.public_lead_form_url(slug, host: default_url_host)
  end

  def iframe_snippet
    "<iframe src=\"#{public_url}\" width=\"100%\" height=\"600\" frameborder=\"0\" title=\"#{ERB::Util.html_escape(name)}\"></iframe>"
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
  end

  def normalize_success_redirect_url
    self.success_redirect_url = success_redirect_url.to_s.strip.presence
  end

  def normalize_hidden_field_keys
    self.hidden_field_keys = Array(hidden_field_keys).map { |key| key.to_s.strip.downcase }.compact_blank.uniq
  end

  def hidden_field_keys_are_valid
    hidden_field_keys.each do |key|
      unless key.match?(HIDDEN_FIELD_KEY_FORMAT)
        errors.add(:hidden_field_keys, "invalid key: #{key}")
        next
      end

      if RESERVED_FIELD_KEYS.include?(key)
        errors.add(:hidden_field_keys, "reserved key: #{key}")
      end
    end
  end

  def normalize_pipeline_routes
    return if pipeline_routes.blank?

    self.pipeline_routes = pipeline_routes.to_h.transform_keys(&:to_s).transform_values { |value| value.presence&.to_i }.compact
  end

  def pipeline_routes_belong_to_workspace
    return if workspace.nil? || pipeline_routes.blank?

    pipeline_routes.each do |help_type, pipeline_id|
      next if workspace.pipelines.exists?(id: pipeline_id)

      errors.add(:pipeline_routes, "invalid pipeline for #{help_type}")
    end
  end

  def associations_belong_to_workspace
    return if workspace.nil?

    errors.add(:pipeline, "must belong to the workspace") if pipeline && pipeline.workspace_id != workspace_id
    errors.add(:product, "must belong to the workspace") if product && product.workspace_id != workspace_id
    if pipeline_stage && pipeline && pipeline_stage.pipeline_id != pipeline_id
      errors.add(:pipeline_stage, "must belong to the selected pipeline")
    end
    errors.add(:email_template, "must belong to the workspace") if email_template && email_template.workspace_id != workspace_id
    errors.add(:responsible, "must be a workspace member") if responsible && !workspace.users.exists?(id: responsible_id)
  end

  def default_url_host
    options = Rails.application.config.action_mailer.default_url_options
    host = options[:host]
    port = options[:port]
    return host if port.blank?

    "#{host}:#{port}"
  end
end
