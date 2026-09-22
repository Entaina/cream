class LeadForm < ApplicationRecord
  DESTINATIONS = %w[deal mql].freeze

  PLACEHOLDER_COMPANY_NAME = "Particulares".freeze
  HONEYPOT_FIELD = "_honeypot".freeze
  TIMESTAMP_FIELD = "_ts".freeze
  # Anti-spam: a human needs at least this long to fill the form.
  MIN_SECONDS_TO_SUBMIT = 3
  # Containment caps: beyond these, submissions are silently discarded.
  MAX_SUBMISSIONS_PER_EMAIL_PER_DAY = 5
  MAX_SUBMISSIONS_PER_FORM_PER_HOUR = 100
  METADATA_FIELDS = %w[
    lead_form_slug lead_form_name source_page referrer cream_aid
    utm_source utm_medium utm_campaign utm_term utm_content
  ].freeze
  SYSTEM_FIELD_KEYS = (
    METADATA_FIELDS + [
      HONEYPOT_FIELD, TIMESTAMP_FIELD, "gdpr_consent", "_submission_key", "privacy_policy_hash",
      Marketing::ConsentService::SUBSCRIBE_ALL_FIELD_KEY, "subscribe_all_label", "subscribe_all_exclude_slugs"
    ]
  ).freeze

  def self.consent_field_keys_for(workspace)
    SubscriptionType.ensure_defaults!(workspace)
    workspace.subscription_types.where.not(consent_field_key: nil).pluck(:consent_field_key)
  end

  def self.system_field_keys_for(workspace)
    (SYSTEM_FIELD_KEYS + consent_field_keys_for(workspace)).uniq
  end
  FIELD_KEY_FORMAT = /\A[a-z][a-z0-9_]{0,39}\z/
  # Datos del envío que viajan como query params a la URL de redirección tras envío,
  # para que el destino (p. ej. una página de reservas) pueda autorrellenarse.
  # Siempre lo que tecleó el visitante, nunca la ficha del CRM: si no, cualquiera
  # que conozca un email podría pescar el nombre y teléfono almacenados de esa persona.
  REDIRECT_PREFILL_KEYS = %w[first_name last_name email phone].freeze

  belongs_to :workspace
  belongs_to :pipeline, optional: true
  belongs_to :pipeline_stage, optional: true
  belongs_to :product, optional: true
  belongs_to :subscription_type, optional: true
  belongs_to :responsible, class_name: "User"
  belongs_to :email_template, optional: true

  has_many :lead_submissions, dependent: :restrict_with_error

  validates :name, :slug, :template_key, presence: true
  validates :destination, inclusion: {in: DESTINATIONS}
  validates :first_task_title, presence: true, if: :deal_destination?
  validates :slug, uniqueness: true, format: {with: /\A[a-z0-9-]+\z/}
  validates :template_key, inclusion: {in: ->(form) { form.class.available_template_keys(workspace: form.workspace) }}
  validates :first_task_due_days, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :success_redirect_url, format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https])}, allow_blank: true
  validate :associations_belong_to_workspace
  validate :pipeline_routes_belong_to_workspace
  validate :pipeline_route_keys_are_valid
  validate :hidden_field_keys_are_valid
  validate :deal_destination_requires_pipeline
  validate :mql_destination_allowed
  validate :subscription_type_belongs_to_workspace

  before_validation :normalize_slug
  before_validation :normalize_success_redirect_url
  before_validation :normalize_hidden_field_keys
  before_validation :normalize_pipeline_routes

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }
  scope :mql_destination, -> { where(destination: "mql") }
  scope :deal_destination, -> { where(destination: "deal") }

  def deal_destination?
    destination == "deal"
  end

  def mql_destination?
    destination == "mql"
  end

  def first_task_due_on(on: Date.current)
    on + first_task_due_days.days
  end

  def configured_stage_for(for_pipeline)
    return if pipeline_stage.nil? || for_pipeline.nil?
    return unless pipeline_stage.pipeline_id == for_pipeline.id

    pipeline_stage
  end

  def resolve_stage(for_pipeline: pipeline)
    configured = configured_stage_for(for_pipeline)
    return configured if configured

    for_pipeline.first_stage
  end

  def resolve_pipeline(help_type: nil)
    route_id = pipeline_routes[help_type.to_s].presence if help_type.present?
    return workspace.pipelines.find(route_id) if route_id.present?

    pipeline
  end

  def help_type_label(help_type)
    help_type.to_s.tr("_", " ").humanize
  end

  def self.build_pipeline_routes_from_form(keys, pipeline_ids)
    Array(keys).zip(Array(pipeline_ids)).each_with_object({}) do |(key, pipeline_id), routes|
      key = key.to_s.strip
      next if key.blank? || pipeline_id.blank?

      routes[key] = pipeline_id
    end
  end

  def resolved_product(product_id_param: nil)
    id = product_id_param.presence || product_id
    return if id.blank?

    workspace.products.find_by(id: id)
  end

  def open_editions_for(product)
    return Edition.none unless product

    product.editions.not_started.order(:starts_on, :name)
  end

  def mql_subscription_type
    subscription_type || workspace.subscription_types.find_by(slug: "general")
  end

  def expected_mql_consent_field_key
    type = mql_subscription_type
    return if type.nil?

    type.consent_field_key.presence || Marketing::ConsentService::LEGACY_FIELD_ALIASES[type.slug]
  end

  def template_consent_field_keys
    template = workspace.lead_form_templates.find_by(path: LeadFormTemplate.form_page_path_for(template_key))
    return [] unless template

    if template.submission_schema.present?
      Array(template.submission_schema["fields"]).map { |field| field["name"] }
    else
      html = LeadFormTemplates::FormHtmlRenderer.render(lead_form: self)
      LeadFormTemplates::HtmlSchema.parse(html).fields.map(&:name)
    end
  end

  def template_includes_consent_field?(key = expected_mql_consent_field_key)
    return true if key.blank?

    template_consent_field_keys.include?(key)
  end

  def self.available_template_keys(workspace: nil)
    return filesystem_template_keys if workspace.nil?

    workspace.lead_form_templates
      .form_pages
      .pluck(:path)
      .filter_map { |path| LeadFormTemplate.template_key_for(path) }
      .uniq
      .sort
  end

  def self.filesystem_template_keys
    Dir.glob(Rails.root.join("lib/lead_form_templates/public/lead_forms/*.liquid")).filter_map do |path|
      key = File.basename(path, ".liquid")
      key unless key.in?(%w[show success privacy])
    end.sort
  end

  def self.filter_submission_params(raw)
    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    hash.stringify_keys.select { |key, _| field_key?(key) }
  end

  def self.field_key?(key)
    key = key.to_s
    return true if key.in?([HONEYPOT_FIELD, TIMESTAMP_FIELD])

    key.match?(FIELD_KEY_FORMAT)
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

  def success_redirect_location(prefill: nil)
    url = success_redirect_url.to_s.strip.presence
    return if url.blank?

    uri = URI.parse(url)
    return unless uri.is_a?(URI::HTTP) && uri.host.present?

    append_redirect_prefill(uri, prefill) if prefill.present?
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

  # Cuelga los datos del envío como query params de la URL de redirección,
  # conservando los que la URL configurada ya trae (ante colisión, gana lo configurado).
  def append_redirect_prefill(uri, prefill)
    configured = Rack::Utils.parse_query(uri.query.to_s)
    extra = prefill.slice(*REDIRECT_PREFILL_KEYS)
      .transform_values { |value| value.to_s.strip }
      .reject { |_, value| value.blank? }
    merged = extra.merge(configured)
    uri.query = Rack::Utils.build_query(merged) if merged.present?
  end

  def normalize_hidden_field_keys
    self.hidden_field_keys = Array(hidden_field_keys).map { |key| key.to_s.strip.downcase }.compact_blank.uniq
  end

  def hidden_field_keys_are_valid
    hidden_field_keys.each do |key|
      unless key.match?(FIELD_KEY_FORMAT)
        errors.add(:hidden_field_keys, :invalid_key, key: key)
        next
      end

      if SYSTEM_FIELD_KEYS.include?(key)
        errors.add(:hidden_field_keys, :reserved_key, key: key)
      end
    end
  end

  def normalize_pipeline_routes
    return if pipeline_routes.blank?

    self.pipeline_routes = pipeline_routes.to_h.transform_keys(&:to_s).transform_values { |value| value.presence&.to_i }.compact
  end

  def pipeline_route_keys_are_valid
    return if pipeline_routes.blank?

    pipeline_routes.each_key do |key|
      next if key.match?(FIELD_KEY_FORMAT)

      errors.add(:pipeline_routes, :invalid_key, key: key)
    end
  end

  def pipeline_routes_belong_to_workspace
    return if workspace.nil? || pipeline_routes.blank?

    pipeline_routes.each do |help_type, pipeline_id|
      next if workspace.pipelines.exists?(id: pipeline_id)

      errors.add(:pipeline_routes, :invalid_pipeline, help_type: help_type)
    end
  end

  def deal_destination_requires_pipeline
    return unless deal_destination?

    errors.add(:pipeline, :required_for_deal_destination) if pipeline.blank?
  end

  def mql_destination_allowed
    return unless mql_destination?

    unless CreamFeatures.enabled?(:mql_pool) && CreamFeatures.enabled?(:marketing_consent)
      errors.add(:destination, :requires_mql_features)
    end
  end

  def subscription_type_belongs_to_workspace
    return if subscription_type.nil? || workspace.nil?

    errors.add(:subscription_type, :must_belong_to_workspace) if subscription_type.workspace_id != workspace_id
  end

  def associations_belong_to_workspace
    return if workspace.nil?

    errors.add(:pipeline, :must_belong_to_workspace) if pipeline && pipeline.workspace_id != workspace_id
    errors.add(:product, :must_belong_to_workspace) if product && product.workspace_id != workspace_id
    if pipeline_stage && pipeline && pipeline_stage.pipeline_id != pipeline_id
      errors.add(:pipeline_stage, :must_belong_to_selected_pipeline)
    end
    errors.add(:email_template, :must_belong_to_workspace) if email_template && email_template.workspace_id != workspace_id
    errors.add(:responsible, :must_be_workspace_member) if responsible && !workspace.users.exists?(id: responsible_id)
  end

  def default_url_host
    options = Rails.application.config.action_mailer.default_url_options
    host = options[:host]
    port = options[:port]
    return host if port.blank?

    "#{host}:#{port}"
  end
end
