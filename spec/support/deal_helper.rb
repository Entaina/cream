# Builds valid deals/people for specs now that deals require a company
# and a next action (future task). Contacts are optional.
module DealHelper
  def create_company!(workspace, name: nil)
    workspace.companies.create!(name: name || "ACME #{SecureRandom.hex(3)}")
  end

  def create_person!(workspace, company: nil, **attrs)
    company ||= create_company!(workspace)
    workspace.people.create!({ first_name: "Pat", last_name: "Doe", company: company }.merge(attrs))
  end

  def create_deal!(workspace, pipeline: nil, stage: nil, company: nil, contacts: nil, **attrs)
    pipeline ||= Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    stage ||= pipeline.first_stage
    company ||= create_company!(workspace)
    contacts ||= [ create_person!(workspace, company: company) ]
    actor = workspace.users.first
    workspace.deals.create!({
      name: "Deal", pipeline: pipeline, pipeline_stage: stage, company: company, contacts: contacts,
      tasks: [ Task.new(title: "Next action", due_on: Date.current + 3, workspace: workspace, user: actor, assignee: actor) ]
    }.merge(attrs))
  end
end

RSpec.configure { |config| config.include DealHelper }
