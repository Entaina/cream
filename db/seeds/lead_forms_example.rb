# frozen_string_literal: true

# Idempotent seed of example public lead capture forms into the organization workspace.
# Add new forms to FORMS; run LeadFormsExample.seed!(workspace:, user:).
module LeadFormsExample
  PIPELINE_NAMES = {
    "formacion" => "Formación",
    "formacion_b2c" => "Formación B2C",
    "consultoria" => "Consultoría",
    "proyectos" => "Proyectos",
    "entrenadores" => "Entrenadores"
  }.freeze

  FORMS = [
    {
      slug: "contacto",
      name: "Contacto",
      template_key: "contacto",
      active: true,
      collects_company: false,
      default_pipeline: "Proyectos",
      pipeline_routes: PIPELINE_NAMES,
      email_template: {
        key: "contacto_lead",
        name: "Contacto — acuse de recibo",
        subject: "Example | Hemos recibido tu solicitud",
        body: <<~BODY.strip
          Hola {first_name}:

          Gracias por contactar con Example. Hemos recibido tu mensaje y lo revisaremos en breve.

          Si nos has pedido información sobre un producto, un servicio o un proyecto, alguien del equipo se pondrá en contacto contigo para resolver tus dudas.

          Un cordial saludo,
        BODY
      }
    },
    {
      slug: "demo",
      name: "Solicitar demo",
      template_key: "demo",
      active: true,
      collects_company: true,
      default_pipeline: "Proyectos",
      pipeline_routes: {},
      email_template: {
        key: "demo_lead",
        name: "Demo — acuse de recibo",
        subject: "Example | Hemos recibido tu solicitud — Demo",
        body: <<~BODY.strip
          Hola {first_name}:

          Gracias por tu interés en una demo de nuestro producto. Hemos recibido tu solicitud y alguien del equipo se pondrá en contacto contigo en breve.

          Un cordial saludo,
        BODY
      }
    },
    {
      slug: "newsletter",
      name: "Newsletter",
      template_key: "newsletter",
      active: true,
      collects_company: false,
      default_pipeline: "Proyectos",
      pipeline_routes: {},
      email_template: {
        key: "newsletter_lead",
        name: "Newsletter — acuse de recibo",
        subject: "Example | Gracias por suscribirte",
        body: <<~BODY.strip
          Hola {first_name}:

          Gracias por suscribirte a la newsletter de Example. Pronto recibirás novedades en tu correo.

          Un cordial saludo,
        BODY
      }
    },
    {
      slug: "liderando-ia-reserva",
      name: "Liderando con IA — Reserva",
      template_key: "liderando_ia_reserva",
      active: true,
      collects_company: false,
      default_pipeline: "Formación B2C",
      pipeline_routes: {},
      email_template: {
        key: "liderando_ia_reserva_lead",
        name: "Liderando con IA — Reserva — acuse de recibo",
        subject: "Example | Hemos recibido tu reserva — Liderando con IA",
        body: <<~BODY.strip
          Hola {first_name}:

          Gracias por tu interés en Liderando con IA. Hemos recibido tu solicitud de reserva y alguien del equipo se pondrá en contacto contigo en breve.

          Un cordial saludo,
        BODY
      }
    },
    {
      slug: "desarrollando-con-ia-reservas",
      name: "Desarrollando con IA — Reservas",
      template_key: "desarrollando_ia_reserva",
      active: true,
      collects_company: false,
      default_pipeline: "Formación B2C",
      pipeline_routes: {},
      email_template: {
        key: "desarrollando_ia_reserva_lead",
        name: "Desarrollando con IA — Reservas — acuse de recibo",
        subject: "Example | Hemos recibido tu reserva — Desarrollando con IA",
        body: <<~BODY.strip
          Hola {first_name}:

          Gracias por tu interés en Desarrollando con IA. Hemos recibido tu solicitud de reserva y alguien del equipo se pondrá en contacto contigo en breve.

          Un cordial saludo,
        BODY
      }
    },
    {
      slug: "entrenadores",
      name: "Entrenadores",
      template_key: "entrenadores",
      active: true,
      collects_company: false,
      default_pipeline: "Entrenadores",
      pipeline_routes: {},
      email_template: {
        key: "entrenadores_lead",
        name: "Entrenadores — acuse de recibo",
        subject: "Example | Hemos recibido tu solicitud — Entrenadores",
        body: <<~BODY.strip
          Hola {first_name}:

          Gracias por contactar con Example. Hemos recibido tu solicitud y alguien del equipo se pondrá en contacto contigo en breve.

          Un cordial saludo,
        BODY
      }
    }
  ].freeze

  def self.seed!(workspace:, user:)
    LeadFormTemplates::Importer.import!(workspace)
    pipelines = ensure_pipelines!(workspace)
    responsible = workspace.briefing_actor || user

    FORMS.map do |definition|
      seed_form!(workspace:, user:, responsible:, pipelines:, definition:)
    end
  end

  def self.seed_form!(workspace:, user:, responsible:, pipelines:, definition:)
    email_template = ensure_email_template!(workspace:, user:, attrs: definition.fetch(:email_template))
    default_pipeline = pipelines.fetch(definition[:default_pipeline]) do
      pipelines.fetch("otro")
    end

    form = workspace.lead_forms.find_or_initialize_by(slug: definition.fetch(:slug))
    form.assign_attributes(
      name: definition.fetch(:name),
      template_key: definition.fetch(:template_key),
      pipeline: default_pipeline,
      responsible: responsible,
      email_template: email_template,
      collects_company: definition.fetch(:collects_company, false),
      active: definition.fetch(:active, true),
      pipeline_routes: build_pipeline_routes(definition.fetch(:pipeline_routes, {}), pipelines)
    )
    form.save!
    form
  end

  def self.build_pipeline_routes(routes, pipelines)
    case routes
    when Hash
      routes.transform_values { |pipeline_name| pipelines.fetch(pipeline_name).id }
    else
      {}
    end
  end

  def self.ensure_email_template!(workspace:, user:, attrs:)
    template = workspace.email_templates.find_or_initialize_by(key: attrs.fetch(:key))
    template.assign_attributes(
      user: user,
      name: attrs.fetch(:name),
      subject: attrs.fetch(:subject),
      body: attrs.fetch(:body),
      shared: true
    )
    template.save!
    template
  end

  def self.ensure_pipelines!(workspace)
    default = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    routes = { "Proyectos" => default, "otro" => default }

    PIPELINE_NAMES.each_value do |name|
      routes[name] = workspace.pipelines.find_by(name: name) || duplicate_pipeline!(default, name: name)
    end

    routes
  end

  def self.duplicate_pipeline!(source, name:)
    copy = source.duplicate(name: name)
    copy.save!
    copy
  end
  private_class_method :duplicate_pipeline!
end
