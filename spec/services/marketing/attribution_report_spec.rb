require "rails_helper"

RSpec.describe Marketing::AttributionReport do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:member) { users(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) { create_lead_form!(workspace, user: member, pipeline: pipeline) }

  def create_submission!(person:, utm_source:)
    deal = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person])
    workspace.lead_submissions.create!(
      lead_form: lead_form,
      deal: deal,
      person: person,
      data: {"email" => person.email},
      metadata: {"utm_source" => utm_source}
    )
  end

  it "filters leads by utm_source" do
    person = create_person!(workspace, email: "attr@example.com")
    create_submission!(person: person, utm_source: "newsletter")
    create_submission!(person: create_person!(workspace, email: "other@example.com"), utm_source: "ads")

    rows = described_class.new(workspace: workspace, utm_source: "newsletter").rows

    expect(rows.sum(&:leads)).to eq(1)
  end

  it "counts mql stages consistently" do
    person = create_person!(workspace, email: "mql@example.com", lifecycle_stage: "sql")
    create_submission!(person: person, utm_source: "web")

    row = described_class.new(workspace: workspace).rows.find { |r| r.key == "web" }

    expect(row.mqls).to eq(1)
  end
end
