# Demo workspace with realistic CRM data. Idempotent: wipes and recreates the demo workspace.
demo = Workspace.find_by(slug: "cream-demo")
demo&.destroy

ActiveRecord::Base.transaction do
  organization_workspace = nil
  if User.organization_workspace_configured?
    org_name = ENV.fetch("CREAM_ORGANIZATION_WORKSPACE_NAME")
    organization_workspace = Workspace.find_or_create_by!(slug: org_name.parameterize) do |record|
      record.name = org_name
    end
    organization_workspace.update!(sales_director_enabled: true, okm_chat_enabled: true)
  end

  workspace = Workspace.create!(name: "Cream Demo", slug: "cream-demo")

  admin = User.find_or_create_by!(email_address: ENV.fetch("CREAM_SEED_ADMIN_EMAIL")) do |u|
    u.name = "Admin Example"
    u.password = ENV.fetch("CREAM_SEED_ADMIN_PASSWORD")
  end
  member = User.find_or_create_by!(email_address: ENV.fetch("CREAM_SEED_MEMBER_EMAIL")) do |u|
    u.name = "Ana Example"
    u.password = ENV.fetch("CREAM_SEED_MEMBER_PASSWORD")
  end
  director = User.find_or_create_by!(email_address: "carlos@example.com") do |u|
    u.name = "Carlos Example"
    u.password = ENV.fetch("CREAM_SEED_MEMBER_PASSWORD")
  end
  workspace.memberships.create!(user: admin, role: "admin")
  workspace.memberships.create!(user: member, role: "salesperson")
  workspace.memberships.create!(user: director, role: "sales_director")

  if organization_workspace
    [ [ admin, "admin" ], [ member, "salesperson" ], [ director, "sales_director" ] ].each do |user, role|
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
    { name: "Vercel", domain: "vercel.com", industry: "Developer Tools", employee_range: "201-500", location: "San Francisco, USA", annual_revenue: 120_000_000, description: "Frontend cloud platform. Creators of Next.js." },
    { name: "Linear", domain: "linear.app", industry: "SaaS", employee_range: "51-200", location: "Remote", annual_revenue: 35_000_000, description: "Issue tracking tool teams actually love." },
    { name: "Notion", domain: "notion.so", industry: "Productivity", employee_range: "501-1000", location: "San Francisco, USA", annual_revenue: 250_000_000, description: "All-in-one workspace for notes, docs and wikis." },
    { name: "Factorial", domain: "factorialhr.com", industry: "HR Tech", employee_range: "501-1000", location: "Barcelona, Spain", annual_revenue: 80_000_000, description: "HR software for SMBs." },
    { name: "Cabify", domain: "cabify.com", industry: "Mobility", employee_range: "1000+", location: "Madrid, Spain", annual_revenue: 600_000_000, description: "Ride-hailing across Spain and Latin America." },
    { name: "Typeform", domain: "typeform.com", industry: "SaaS", employee_range: "201-500", location: "Barcelona, Spain", annual_revenue: 95_000_000, description: "People-friendly forms and surveys." },
    { name: "Wallapop", domain: "wallapop.com", industry: "Marketplace", employee_range: "201-500", location: "Barcelona, Spain", annual_revenue: 70_000_000, description: "Second-hand marketplace." },
    { name: "Stripe", domain: "stripe.com", industry: "Fintech", employee_range: "1000+", location: "Dublin, Ireland", annual_revenue: 1_000_000_000, description: "Payments infrastructure for the internet." },
    { name: "StartupXYZ", domain: "startupxyz.io", industry: "SaaS", employee_range: "1-10", location: "Bilbao, Spain", annual_revenue: 500_000, description: "Early-stage startup." }
  ]

  companies = companies_data.map do |attrs|
    workspace.companies.create!(attrs.merge(owner: [ admin, member ].sample))
  end

  people_data = [
    { first_name: "Guillermo", last_name: "Rauch", email: "guillermo@vercel.com", job_title: "CEO", company: "Vercel", location: "San Francisco, USA", phone: "+1 415 555 0101" },
    { first_name: "Karri", last_name: "Saarinen", email: "karri@linear.app", job_title: "CEO & Co-founder", company: "Linear", location: "Helsinki, Finland" },
    { first_name: "Tuomas", last_name: "Artman", email: "tuomas@linear.app", job_title: "CTO", company: "Linear", location: "Zurich, Switzerland" },
    { first_name: "Ivan", last_name: "Zhao", email: "ivan@notion.so", job_title: "CEO", company: "Notion", location: "San Francisco, USA" },
    { first_name: "Jordi", last_name: "Romero", email: "jordi@factorialhr.com", job_title: "CEO", company: "Factorial", location: "Barcelona, Spain", phone: "+34 600 111 222" },
    { first_name: "Bernat", last_name: "Farrero", email: "bernat@factorialhr.com", job_title: "CRO", company: "Factorial", location: "Barcelona, Spain" },
    { first_name: "Juan", last_name: "de Antonio", email: "juan@cabify.com", job_title: "CEO", company: "Cabify", location: "Madrid, Spain" },
    { first_name: "Laura", last_name: "Sanz", email: "laura.sanz@typeform.com", job_title: "VP Sales", company: "Typeform", location: "Barcelona, Spain", phone: "+34 655 333 444" },
    { first_name: "Marc", last_name: "Vidal", email: "marc.vidal@wallapop.com", job_title: "Head of Partnerships", company: "Wallapop", location: "Barcelona, Spain" },
    { first_name: "Patrick", last_name: "Collison", email: "patrick@stripe.com", job_title: "CEO", company: "Stripe", location: "San Francisco, USA" },
    { first_name: "Sara", last_name: "Moreno", email: "sara.moreno@typeform.com", job_title: "Independent consultant", company: "Typeform", location: "Valencia, Spain" },
    { first_name: "David", last_name: "García", email: "david@startupxyz.io", job_title: "Founder", company: "StartupXYZ", location: "Bilbao, Spain" }
  ]

  people = people_data.map do |attrs|
    company_name = attrs.delete(:company)
    company = companies.find { |c| c.name == company_name }
    workspace.people.create!(attrs.merge(company: company, owner: [ admin, member ].sample))
  end

  deals_data = [
    { name: "Vercel — Enterprise plan", stage: "negotiation", value: 48_000, probability: 70, close_in: 20, company: "Vercel", contact: "guillermo@vercel.com" },
    { name: "Linear — Team expansion", stage: "proposal", value: 18_500, probability: 55, close_in: 35, company: "Linear", contact: "karri@linear.app" },
    { name: "Notion — Annual contract", stage: "qualified", value: 65_000, probability: 35, close_in: 60, company: "Notion", contact: "ivan@notion.so" },
    { name: "Factorial — Integration partnership", stage: "won", value: 32_000, probability: 100, close_in: -10, company: "Factorial", contact: "jordi@factorialhr.com" },
    { name: "Cabify — Pilot program", stage: "lead", value: 12_000, probability: 15, close_in: 90, company: "Cabify", contact: "juan@cabify.com" },
    { name: "Typeform — Renewal + upsell", stage: "negotiation", value: 27_500, probability: 80, close_in: 12, company: "Typeform", contact: "laura.sanz@typeform.com" },
    { name: "Wallapop — API licensing", stage: "proposal", value: 22_000, probability: 45, close_in: 40, company: "Wallapop", contact: "marc.vidal@wallapop.com" },
    { name: "Stripe — Co-marketing deal", stage: "lead", value: 8_000, probability: 10, close_in: 120, company: "Stripe", contact: "patrick@stripe.com" },
    { name: "StartupXYZ — Starter plan", stage: "lost", value: 4_500, probability: 0, close_in: -30, company: "StartupXYZ", contact: "david@startupxyz.io" }
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
    deal_owner = [ admin, member ].sample
    workspace.deals.create!(
      attrs.merge(
        pipeline: pipeline, pipeline_stage: stage,
        company: company, contacts: [ contact ].compact, owner: deal_owner,
        expected_close_date: Date.current + close_in.days, position: (position += 1),
        tasks: [ Task.new(title: "Next action — #{attrs[:name]}", due_on: Date.current + 7.days,
          workspace: workspace, user: deal_owner, assignee: deal_owner) ]
      )
    )
  end

  products = [
    { name: "Plan Pro (anual)", description: "Suscripción anual al plan Pro, por usuario.", price: 1_200 },
    { name: "Plan Enterprise (anual)", description: "Plan Enterprise con soporte dedicado y SLA.", price: 6_000 },
    { name: "Onboarding & setup", description: "Implementación inicial y migración de datos.", price: 2_500 },
    { name: "Add-on Analytics", description: "Módulo de analítica avanzada.", price: 800 },
    { name: "Horas de consultoría", description: "Bloque de consultoría técnica (por hora).", price: 90 }
  ].map { |attrs| workspace.products.create!(attrs) }

  # Product lines on a few deals (deal value is recomputed from the lines).
  deals[0].deal_products.create!(product: products[1], quantity: 6)            # Vercel — 6× Enterprise
  deals[0].deal_products.create!(product: products[2], quantity: 1)            # + onboarding
  deals[0].deal_accesses.create!(user: member) if deals[0].owner != member          # shared with member (salesperson)
  deals[1].deal_products.create!(product: products[0], quantity: 12)           # Linear — 12× Pro
  deals[5].deal_products.create!(product: products[0], quantity: 20, unit_price: 1_000) # Typeform — negotiated price

  notes_data = [
    [ deals[0], admin, "Pricing pushback", "Guillermo wants a 15% discount for the 3-year commitment. Need approval from finance before Friday." ],
    [ deals[1], member, "Demo recap", "Showed the workflow builder. Karri loved the API-first approach. Sending the proposal this week." ],
    [ deals[5], admin, nil, "Renewal confirmed verbally. Upsell to the analytics add-on still under discussion." ],
    [ companies[3], member, "Partnership context", "They want to embed our widget in their marketplace. Legal review pending on data processing terms." ],
    [ people[0], admin, nil, "Met at Next.js Conf. Prefers async communication, email over calls." ],
    [ people[7], member, "Intro call", "Laura is the decision maker for the renewal. Budget cycle closes in Q3." ]
  ]
  notes_data.each do |record, author, title, body|
    record.notes.create!(workspace: workspace, user: author, title: title, body: body)
  end

  tasks_data = [
    [ deals[0], admin, admin, "Send revised pricing to Guillermo", 2 ],
    [ deals[1], member, member, "Write proposal for Linear", 4 ],
    [ deals[5], admin, member, "Prepare renewal contract", 1 ],
    [ companies[2], member, admin, "Research Notion's procurement process", 7 ],
    [ people[4], admin, admin, "Follow up with Jordi after legal review", -2 ],
    [ nil, member, member, "Clean up duplicate contacts", 10 ],
    [ deals[3], admin, admin, "Kick-off call with Factorial team", -5 ]
  ]
  tasks_data.each_with_index do |(record, creator, assignee, title, due_in), i|
    task = workspace.tasks.create!(taskable: record, user: creator, assignee: assignee, title: title, due_on: Date.current + due_in.days)
    task.update!(completed_at: 1.day.ago) if i == 6
  end

  hot = workspace.lists.create!(name: "Hot deals Q3", record_type: "Deal", color: "red")
  [ deals[0], deals[5], deals[1] ].each { |d| hot.list_entries.create!(record: d) }

  champions = workspace.lists.create!(name: "Champions", record_type: "Person", color: "hoki")
  [ people[0], people[4], people[7] ].each { |p| champions.list_entries.create!(record: p) }

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
