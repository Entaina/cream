require "rails_helper"

RSpec.describe ReportDrillDown do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:owner) { users(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }

  def drill_down(record_type:, group_by:, row_key:, date_range: "all", pipeline_id: nil, include_closed: false)
    row = ReportRunner::Row.new(
      key: row_key,
      label: "Label",
      value: 1,
      color: nil,
      segments: nil
    )
    described_class.new(
      config: {
        record_type: record_type,
        group_by: group_by,
        date_range: date_range,
        pipeline_id: pipeline_id,
        include_closed: include_closed
      },
      row: row,
      workspace: workspace
    ).path
  end

  it "links deal stage bars to the deals index with stage and closed params" do
    stage = pipeline.pipeline_stages.first

    path = drill_down(record_type: "Deal", group_by: "stage", row_key: stage.id)

    expect(path).to include("/deals")
    expect(path).to include("stage=#{stage.id}")
    expect(path).to include("pipeline_id=all")
  end

  it "links closed deal stage bars with closed=1" do
    won_stage = pipeline.pipeline_stages.find_by!(name: "Won")

    path = drill_down(record_type: "Deal", group_by: "stage", row_key: won_stage.id)

    expect(path).to include("closed=1")
    expect(path).to include("stage=#{won_stage.id}")
  end

  it "links unassigned owner bars with owner_id=none" do
    path = drill_down(record_type: "Person", group_by: "owner", row_key: nil)

    expect(path).to include("/people")
    expect(path).to include("owner_id=none")
  end

  it "links company bars with company_id" do
    company = create_company!(workspace)

    path = drill_down(record_type: "Person", group_by: "company", row_key: company.id)

    expect(path).to include("company_id=#{company.id}")
  end

  it "links month bars with created_from and created_to for that month" do
    month = Time.zone.local(2025, 3, 15)

    path = drill_down(record_type: "Deal", group_by: "month", row_key: month)

    expect(path).to include("created_from=2025-03-01")
    expect(path).to include("created_to=2025-03-31")
  end

  it "adds created_from for non-month groups when the report has a date range" do
    path = drill_down(record_type: "Company", group_by: "owner", row_key: owner.id, date_range: "year")

    expect(path).to include("created_from=#{Date.current.beginning_of_year}")
    expect(path).to include("owner_id=#{owner.id}")
  end

  it "links blank industry bars with industry=none" do
    path = drill_down(record_type: "Company", group_by: "industry", row_key: nil)

    expect(path).to include("industry=none")
  end

  it "passes the report pipeline_id when present" do
    path = drill_down(record_type: "Deal", group_by: "owner", row_key: owner.id, pipeline_id: pipeline.id)

    expect(path).to include("pipeline_id=#{pipeline.id}")
  end
end
