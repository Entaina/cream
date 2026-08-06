require "rails_helper"

RSpec.describe BookingSubmissionProcessor, type: :service do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "processor-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: [ "primary" ]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: { "es" => "Online" },
      duration_minutes: 30,
      location_type: "google_meet",
      weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 0,
      visible: true
    )
    page.save!
    page
  end
  let(:event_type) { booking_page.event_types.find_by!(slug: "video") }
  let(:request) { instance_double(ActionDispatch::Request, remote_ip: "127.0.0.1", user_agent: "rspec") }
  let(:params) do
    {
      "first_name" => "Ana",
      "last_name" => "Lopez",
      "email" => "ana@example.com"
    }
  end

  def process
    described_class.call(
      booking_page: booking_page,
      event_type: event_type,
      params: params,
      request: request
    )
  end

  it "creates a person and deal when none exist" do
    expect {
      result = process
      expect(result.person.email).to eq("ana@example.com")
      expect(result.deal.pipeline).to eq(pipeline)
      expect(result.deal.pipeline_stage).to eq(pipeline.first_stage)
      expect(result.deal.contacts).to contain_exactly(result.person)
      expect(result.deal.tasks.map(&:title)).to include("Preparar reunión reservada")
    }.to change(Person, :count).by(1)
      .and change(Deal, :count).by(1)
  end

  it "reuses an existing deal in the target pipeline and stage for the same email" do
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "ana@example.com", first_name: "Ana", last_name: "Lopez")
    existing_deal = create_deal!(
      workspace,
      pipeline: pipeline,
      stage: pipeline.first_stage,
      company: company,
      contacts: [ person ],
      name: "Existing deal"
    )

    expect { process }.to change(Person, :count).by(0)
      .and change(Deal, :count).by(0)

    result = process
    expect(result.deal).to eq(existing_deal)
    expect(result.person).to eq(person)
  end

  it "creates a new deal when the person has a deal in another stage of the same pipeline" do
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "ana@example.com")
    qualified_stage = pipeline.pipeline_stages.find_by!(name: "Qualified")
    create_deal!(
      workspace,
      pipeline: pipeline,
      stage: qualified_stage,
      company: company,
      contacts: [ person ]
    )

    expect { process }.to change(Deal, :count).by(1)

    result = process
    expect(result.deal.pipeline_stage).to eq(pipeline.first_stage)
  end

  it "creates a new deal when the person has a deal in another pipeline" do
    other_pipeline = pipeline.duplicate(name: "Other")
    other_pipeline.save!
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "ana@example.com")
    create_deal!(
      workspace,
      pipeline: other_pipeline,
      company: company,
      contacts: [ person ]
    )

    expect { process }.to change(Deal, :count).by(1)

    result = process
    expect(result.deal.pipeline).to eq(pipeline)
  end
end
