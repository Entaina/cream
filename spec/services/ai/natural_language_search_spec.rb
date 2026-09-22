require "rails_helper"

RSpec.describe Ai::NaturalLanguageSearch do
  fixtures :users, :workspaces, :companies, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:people_scope) { workspace.people }
  let(:companies_scope) { workspace.companies }
  let(:deals_scope) { workspace.deals }
  let(:tasks_scope) { workspace.tasks }

  def search(query, user: nil)
    described_class.new(
      workspace: workspace,
      query: query,
      user: user,
      people_scope: people_scope,
      companies_scope: companies_scope,
      deals_scope: deals_scope,
      tasks_scope: tasks_scope
    ).call
  end

  it "finds overdue tasks from a natural-language query" do
    person = create_person!(workspace, company: companies(:acme))
    person.tasks.create!(title: "Late task", due_on: Date.current - 1, workspace: workspace, user: user, assignee: user)

    result = search("overdue tasks")

    expect(result.interpretation).to eq(I18n.t("ai_search.interpretations.overdue_tasks"))
    expect(result.tasks.map(&:title)).to include("Late task")
  end

  it "finds overdue tasks from a Spanish query" do
    person = create_person!(workspace, company: companies(:acme))
    person.tasks.create!(title: "Tarea atrasada", due_on: Date.current - 1, workspace: workspace, user: user, assignee: user)

    result = search("tareas atrasadas")

    expect(result.tasks.map(&:title)).to include("Tarea atrasada")
  end

  it "finds tasks due today from a Spanish query" do
    person = create_person!(workspace, company: companies(:acme))
    person.tasks.create!(title: "Para hoy", due_on: Date.current, workspace: workspace, user: user, assignee: user)
    person.tasks.create!(title: "Mañana", due_on: Date.current + 1, workspace: workspace, user: user, assignee: user)

    result = search("tareas para hoy")

    expect(result.tasks.map(&:title)).to include("Para hoy")
    expect(result.tasks.map(&:title)).not_to include("Mañana")
  end

  it "finds today and overdue tasks from a combined Spanish query" do
    person = create_person!(workspace, company: companies(:acme))
    person.tasks.create!(title: "Atrasada", due_on: Date.current - 2, workspace: workspace, user: user, assignee: user)
    person.tasks.create!(title: "Hoy", due_on: Date.current, workspace: workspace, user: user, assignee: user)
    person.tasks.create!(title: "Futura", due_on: Date.current + 4, workspace: workspace, user: user, assignee: user)

    result = search("tareas atrasadas o para hoy", user: user)

    titles = result.tasks.map(&:title)
    expect(titles).to include("Atrasada", "Hoy")
    expect(titles).not_to include("Futura")
  end

  it "falls back to keyword search" do
    company = companies(:acme)

    result = search(company.name)

    expect(result.companies.map(&:id)).to include(company.id)
  end

  it "finds tasks linked to a company by name" do
    company = companies(:acme)
    person = create_person!(workspace, company: company)
    pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    open_deal = create_deal!(workspace, pipeline: pipeline, company: company, name: "Acme opp", contacts: [])
    open_deal.tasks.create!(title: "Deal follow-up", due_on: Date.current, workspace: workspace, user: user, assignee: user)
    company.tasks.create!(title: "Company follow-up", due_on: Date.current, workspace: workspace, user: user, assignee: user)
    person.tasks.create!(title: "Person follow-up", due_on: Date.current, workspace: workspace, user: user, assignee: user)

    result = search("tareas de Acme Corp")

    expect(result.interpretation).to include(I18n.t("ai_search.record_types.company"))
    expect(result.tasks.map(&:title)).to include("Company follow-up")
    expect(result.tasks.map(&:title)).not_to include("Person follow-up")
    deal_titles = result.open_deal_tasks.flat_map { |group| group[:tasks].map(&:title) }
    expect(deal_titles).to include("Deal follow-up")
  end

  it "finds tasks linked to a contact by name" do
    company = companies(:acme)
    person = create_person!(workspace, company: company, first_name: "Ana", last_name: "Lopez")
    person.tasks.create!(title: "Call Ana", due_on: Date.current, workspace: workspace, user: user, assignee: user)

    result = search("tareas del contacto Ana Lopez")

    expect(result.tasks.map(&:title)).to include("Call Ana")
  end

  it "finds tasks assigned to a workspace user by name" do
    other_user = users(:two)
    workspace.memberships.find_or_create_by!(user: other_user)
    person = create_person!(workspace, company: companies(:acme))
    person.tasks.create!(title: "User Two task", due_on: Date.current, workspace: workspace, user: other_user, assignee: other_user)
    person.tasks.create!(title: "My task", due_on: Date.current, workspace: workspace, user: user, assignee: user)

    result = search("tareas asignadas a User Two")

    expect(result.interpretation).to include("User Two")
    expect(result.tasks.map(&:title)).to include("User Two task")
    expect(result.tasks.map(&:title)).not_to include("My task")
  end
end
