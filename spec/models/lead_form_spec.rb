require "rails_helper"

RSpec.describe LeadForm, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  it "is valid with default first task settings" do
    form = create_lead_form!(workspace, user: member)

    expect(form).to be_valid
    expect(form.first_task_title).to eq("Contactar lead")
    expect(form.first_task_due_days).to eq(1)
  end

  it "requires first task title" do
    form = create_lead_form!(workspace, user: member)
    form.first_task_title = ""

    expect(form).not_to be_valid
    expect(form.errors[:first_task_title]).to be_present
  end

  it "rejects negative first task due days" do
    form = create_lead_form!(workspace, user: member)
    form.first_task_due_days = -1

    expect(form).not_to be_valid
    expect(form.errors[:first_task_due_days]).to be_present
  end

  it "computes first task due date from configured days relative to a given date" do
    form = create_lead_form!(workspace, user: member, first_task_due_days: 4)
    submission_day = Date.new(2026, 8, 10)

    expect(form.first_task_due_on(on: submission_day)).to eq(Date.new(2026, 8, 14))
  end

  it "includes workspace-specific template keys" do
    workspace.lead_form_templates.create!(
      path: "public/lead_forms/custom_workspace",
      partial: false,
      body: "<div class=\"mx-auto max-w-xl\"><p>custom</p></div>"
    )

    expect(described_class.available_template_keys(workspace: workspace)).to include("custom_workspace")
  end
end
