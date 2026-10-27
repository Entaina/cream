# Demo workspace with realistic CRM data. Idempotent: wipes and recreates the demo workspace.
demo = Workspace.find_by(slug: "cream-demo")
demo&.destroy

ActiveRecord::Base.transaction do
  organization_workspace = nil
  if User.organization_workspace_configured?
    org_name = ENV.fetch("CREAM_ORGANIZATION_WORKSPACE_NAME")
    organization_workspace = Workspace.find_or_create_by!(slug: org_name.parameterize) do |record|
      record.name = org_name
      record.time_zone = "Europe/Madrid"
    end
    organization_workspace.update!(sales_director_enabled: true, okm_chat_enabled: true, time_zone: "Europe/Madrid")
  end

  workspace = Workspace.create!(name: "Cream Demo", slug: "cream-demo")

  admin = User.find_or_create_by!(email_address: ENV.fetch("CREAM_SEED_ADMIN_EMAIL")) do |u|
    u.name = "Admin Example"
    u.password = ENV.fetch("CREAM_SEED_ADMIN_PASSWORD")
    u.email_verified_at = Time.current
  end
  member = User.find_or_create_by!(email_address: ENV.fetch("CREAM_SEED_MEMBER_EMAIL")) do |u|
    u.name = "Ana Example"
    u.password = ENV.fetch("CREAM_SEED_MEMBER_PASSWORD")
    u.email_verified_at = Time.current
  end
  director = User.find_or_create_by!(email_address: "carlos@example.com") do |u|
    u.name = "Carlos Example"
    u.password = ENV.fetch("CREAM_SEED_MEMBER_PASSWORD")
    u.email_verified_at = Time.current
  end
  [admin, member, director].each do |user|
    user.update!(email_verified_at: Time.current) if user.email_verified_at.nil?
  end
  workspace.memberships.create!(user: admin, role: "admin")
  workspace.memberships.create!(user: member, role: "salesperson")
  workspace.memberships.create!(user: director, role: "sales_director")

  if organization_workspace
    [[admin, "admin"], [member, "salesperson"], [director, "sales_director"]].each do |user, role|
      next unless User.organization_email?(user.email_address)

      organization_workspace.memberships.find_or_create_by!(user: user) do |membership|
        membership.role = role
      end
    end

    load Rails.root.join("db/seeds/email_templates_example.rb")
    EmailTemplatesExample.seed!(workspace: organization_workspace, user: admin)

    load Rails.root.join("db/seeds/lead_forms_example.rb")
    LeadFormsExample.seed!(workspace: organization_workspace, user: admin)

    load Rails.root.join("db/seeds/booking_pages_example.rb")
    BookingPagesExample.seed!(workspace: organization_workspace, user: admin)
  end

  companies_data = [
    {name: "Nimbus Cloud", domain: "nimbuscloud.example", industry: "Developer Tools", employee_range: "201-500", location: "San Francisco, USA", annual_revenue: 120_000_000, description: "Frontend cloud platform for web teams."},
    {name: "Trackwise", domain: "trackwise.example", industry: "SaaS", employee_range: "51-200", location: "Remote", annual_revenue: 35_000_000, description: "Issue tracking tool teams actually love."},
    {name: "Pagecraft", domain: "pagecraft.example", industry: "Productivity", employee_range: "501-1000", location: "San Francisco, USA", annual_revenue: 250_000_000, description: "All-in-one workspace for notes, docs and wikis."},
    {name: "Plantilla HR", domain: "plantillahr.example", industry: "HR Tech", employee_range: "501-1000", location: "Barcelona, Spain", annual_revenue: 80_000_000, description: "HR software for SMBs."},
    {name: "Rutas", domain: "rutas.example", industry: "Mobility", employee_range: "1000+", location: "Madrid, Spain", annual_revenue: 600_000_000, description: "Ride-hailing across Spain and Latin America."},
    {name: "Formulae", domain: "formulae.example", industry: "SaaS", employee_range: "201-500", location: "Barcelona, Spain", annual_revenue: 95_000_000, description: "People-friendly forms and surveys."},
    {name: "Segunda Mano", domain: "segundamano.example", industry: "Marketplace", employee_range: "201-500", location: "Barcelona, Spain", annual_revenue: 70_000_000, description: "Second-hand marketplace."},
    {name: "Paylane", domain: "paylane.example", industry: "Fintech", employee_range: "1000+", location: "Dublin, Ireland", annual_revenue: 1_000_000_000, description: "Payments infrastructure for the internet."},
    {name: "StartupXYZ", domain: "startupxyz.example", industry: "SaaS", employee_range: "1-10", location: "Bilbao, Spain", annual_revenue: 500_000, description: "Early-stage startup."}
  ]

  companies = companies_data.map do |attrs|
    workspace.companies.create!(attrs.merge(owner: [admin, member].sample))
  end

  people_data = [
    {first_name: "Elena", last_name: "Ríos", email: "elena@nimbuscloud.example", job_title: "CEO", company: "Nimbus Cloud", location: "San Francisco, USA", phone: "+1 415 555 0101"},
    {first_name: "Mikko", last_name: "Laine", email: "mikko@trackwise.example", job_title: "CEO & Co-founder", company: "Trackwise", location: "Helsinki, Finland"},
    {first_name: "Lukas", last_name: "Weber", email: "lukas@trackwise.example", job_title: "CTO", company: "Trackwise", location: "Zurich, Switzerland"},
    {first_name: "Grace", last_name: "Chen", email: "grace@pagecraft.example", job_title: "CEO", company: "Pagecraft", location: "San Francisco, USA"},
    {first_name: "Pau", last_name: "Serra", email: "pau@plantillahr.example", job_title: "CEO", company: "Plantilla HR", location: "Barcelona, Spain", phone: "+34 600 111 222"},
    {first_name: "Marta", last_name: "Vila", email: "marta@plantillahr.example", job_title: "CRO", company: "Plantilla HR", location: "Barcelona, Spain"},
    {first_name: "Javier", last_name: "Ortega", email: "javier@rutas.example", job_title: "CEO", company: "Rutas", location: "Madrid, Spain"},
    {first_name: "Lucía", last_name: "Navarro", email: "lucia.navarro@formulae.example", job_title: "VP Sales", company: "Formulae", location: "Barcelona, Spain", phone: "+34 655 333 444"},
    {first_name: "Oriol", last_name: "Puig", email: "oriol.puig@segundamano.example", job_title: "Head of Partnerships", company: "Segunda Mano", location: "Barcelona, Spain"},
    {first_name: "Sean", last_name: "Murphy", email: "sean@paylane.example", job_title: "CEO", company: "Paylane", location: "San Francisco, USA"},
    {first_name: "Sara", last_name: "Moreno", email: "sara.moreno@formulae.example", job_title: "Independent consultant", company: "Formulae", location: "Valencia, Spain"},
    {first_name: "David", last_name: "García", email: "david@startupxyz.example", job_title: "Founder", company: "StartupXYZ", location: "Bilbao, Spain"}
  ]

  people = people_data.map do |attrs|
    company_name = attrs.delete(:company)
    company = companies.find { |c| c.name == company_name }
    workspace.people.create!(attrs.merge(company: company, owner: [admin, member].sample))
  end

  deals_data = [
    {name: "Nimbus Cloud — Enterprise plan", stage: "negotiation", value: 48_000, probability: 70, close_in: 20, company: "Nimbus Cloud", contact: "elena@nimbuscloud.example"},
    {name: "Trackwise — Team expansion", stage: "proposal", value: 18_500, probability: 55, close_in: 35, company: "Trackwise", contact: "mikko@trackwise.example"},
    {name: "Pagecraft — Annual contract", stage: "qualified", value: 65_000, probability: 35, close_in: 60, company: "Pagecraft", contact: "grace@pagecraft.example"},
    {name: "Plantilla HR — Integration partnership", stage: "won", value: 32_000, probability: 100, close_in: -10, company: "Plantilla HR", contact: "pau@plantillahr.example"},
    {name: "Rutas — Pilot program", stage: "lead", value: 12_000, probability: 15, close_in: 90, company: "Rutas", contact: "javier@rutas.example"},
    {name: "Formulae — Renewal + upsell", stage: "negotiation", value: 27_500, probability: 80, close_in: 12, company: "Formulae", contact: "lucia.navarro@formulae.example"},
    {name: "Segunda Mano — API licensing", stage: "proposal", value: 22_000, probability: 45, close_in: 40, company: "Segunda Mano", contact: "oriol.puig@segundamano.example"},
    {name: "Paylane — Co-marketing deal", stage: "lead", value: 8_000, probability: 10, close_in: 120, company: "Paylane", contact: "sean@paylane.example"},
    {name: "StartupXYZ — Starter plan", stage: "lost", value: 4_500, probability: 0, close_in: -30, company: "StartupXYZ", contact: "david@startupxyz.example"}
  ]

  # The default "Ventas" pipeline is created automatically with the workspace.
  pipeline = Pipeline.default_for(workspace)
  stage_by_key = pipeline.pipeline_stages.ordered.index_by { |s| s.name.downcase }

  position = 0
  deals = deals_data.map do |attrs|
    company_name = attrs.delete(:company)
    contact_email = attrs.delete(:contact)
    stage = stage_by_key.fetch(attrs.delete(:stage))
    company = companies.find { |c| c.name == company_name }
    contact = people.find { |p| p.email == contact_email }
    close_in = attrs.delete(:close_in)
    deal_owner = [admin, member].sample
    workspace.deals.create!(
      attrs.merge(
        pipeline: pipeline, pipeline_stage: stage,
        company: company, contacts: [contact].compact, owner: deal_owner,
        expected_close_date: Date.current + close_in.days, position: (position += 1),
        tasks: [Task.new(title: "Next action — #{attrs[:name]}", due_on: Date.current + 7.days,
          workspace: workspace, user: deal_owner, assignee: deal_owner)]
      )
    )
  end

  products = [
    {name: "Plan Pro (anual)", description: "Suscripción anual al plan Pro, por usuario.", price: 1_200},
    {name: "Plan Enterprise (anual)", description: "Plan Enterprise con soporte dedicado y SLA.", price: 6_000},
    {name: "Onboarding & setup", description: "Implementación inicial y migración de datos.", price: 2_500},
    {name: "Add-on Analytics", description: "Módulo de analítica avanzada.", price: 800},
    {name: "Horas de consultoría", description: "Bloque de consultoría técnica (por hora).", price: 90}
  ].map { |attrs| workspace.products.create!(attrs) }

  # Product lines on a few deals (deal value is recomputed from the lines).
  deals[0].deal_products.create!(product: products[1], quantity: 6)            # Nimbus Cloud — 6× Enterprise
  deals[0].deal_products.create!(product: products[2], quantity: 1)            # + onboarding
  deals[0].deal_accesses.create!(user: member) if deals[0].owner != member          # shared with member (salesperson)
  deals[1].deal_products.create!(product: products[0], quantity: 12)           # Trackwise — 12× Pro
  deals[5].deal_products.create!(product: products[0], quantity: 20, unit_price: 1_000) # Formulae — negotiated price

  notes_data = [
    [deals[0], admin, "Pricing pushback", "Elena wants a 15% discount for the 3-year commitment. Need approval from finance before Friday."],
    [deals[1], member, "Demo recap", "Showed the workflow builder. Mikko loved the API-first approach. Sending the proposal this week."],
    [deals[5], admin, nil, "Renewal confirmed verbally. Upsell to the analytics add-on still under discussion."],
    [companies[3], member, "Partnership context", "They want to embed our widget in their marketplace. Legal review pending on data processing terms."],
    [people[0], admin, nil, "Met at a frontend conference. Prefers async communication, email over calls."],
    [people[7], member, "Intro call", "Lucía is the decision maker for the renewal. Budget cycle closes in Q3."]
  ]
  notes_data.each do |record, author, title, body|
    record.notes.create!(workspace: workspace, user: author, title: title, body: body)
  end

  tasks_data = [
    [deals[0], admin, admin, "Send revised pricing to Elena", 2],
    [deals[1], member, member, "Write proposal for Trackwise", 4],
    [deals[5], admin, member, "Prepare renewal contract", 1],
    [companies[2], member, admin, "Research Pagecraft's procurement process", 7],
    [people[4], admin, admin, "Follow up with Pau after legal review", -2],
    [nil, member, member, "Clean up duplicate contacts", 10],
    [deals[3], admin, admin, "Kick-off call with Plantilla HR team", -5]
  ]
  tasks_data.each_with_index do |(record, creator, assignee, title, due_in), i|
    task = workspace.tasks.create!(taskable: record, user: creator, assignee: assignee, title: title, due_on: Date.current + due_in.days)
    task.update!(completed_at: 1.day.ago) if i == 6
  end

  hot = workspace.lists.create!(name: "Hot deals Q3", record_type: "Deal", color: "red")
  [deals[0], deals[5], deals[1]].each { |d| hot.list_entries.create!(record: d) }

  champions = workspace.lists.create!(name: "Champions", record_type: "Person", color: "hoki")
  [people[0], people[4], people[7]].each { |p| champions.list_entries.create!(record: p) }

  spain = workspace.lists.create!(name: "Spain accounts", record_type: "Company", color: "golden")
  companies.select { |c| c.location.to_s.include?("Spain") }.each { |c| spain.list_entries.create!(record: c) }

  # Seed-time activities have no Current.user; attribute them to the record owner.
  workspace.activities.where(user: nil).includes(:subject).find_each do |activity|
    owner_id = activity.subject.try(:owner_id) || admin.id
    activity.update_columns(user_id: owner_id)
  end

  puts "Seeded workspace '#{workspace.name}': #{workspace.companies.count} companies, #{workspace.people.count} people, #{workspace.deals.count} deals."
  if organization_workspace
    org_members = organization_workspace.users.pluck(:email_address).join(", ")
    template_count = organization_workspace.email_templates.where.not(key: nil).count
    lead_form_template_count = organization_workspace.lead_form_templates.count
    lead_form_count = organization_workspace.lead_forms.count
    booking_page_count = organization_workspace.booking_pages.count
    puts "Organization workspace '#{organization_workspace.name}': #{org_members.presence || "no members"} (#{template_count} email templates, #{lead_form_template_count} lead form templates, #{lead_form_count} lead forms, #{booking_page_count} booking pages)"
  end
  puts "Login: #{ENV.fetch("CREAM_SEED_ADMIN_EMAIL")} / #{ENV.fetch("CREAM_SEED_ADMIN_PASSWORD")}"
end
