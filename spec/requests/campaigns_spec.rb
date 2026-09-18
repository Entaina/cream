require "rails_helper"

RSpec.describe "Campaigns", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:workspace) { workspaces(:one) }

  let(:journey) do
    workspace.journeys.create!(name: "Nurture", entry_trigger: "manual", max_reenrollments: 0, active: true).tap do |record|
      record.steps.create!(position: 0, step_type: "wait", active: true, config: {"minutes" => 60})
    end
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
    sign_in_as(admin)
  end

  it "creates a campaign with inline email content" do
    post campaigns_path, params: {
      campaign: {
        name: "Marzo",
        status: "draft",
        email_subject: "Hola",
        email_body: "<p>Contenido</p>",
        email_body_editor: "html"
      }
    }

    campaign = Campaign.last
    expect(response).to redirect_to(campaign)
    expect(campaign.email_subject).to eq("Hola")
    expect(campaign.email_body).to include("Contenido")
  end

  it "blocks send when campaign has no email content" do
    campaign = workspace.campaigns.create!(name: "Vacía", status: "draft")
    segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})

    post send_campaign_campaign_path(campaign), params: {segment_id: segment.id}

    expect(response).to redirect_to(edit_campaign_path(campaign))
    expect(flash[:alert]).to include(I18n.t("flashes.campaigns.missing_email_content"))
    expect(campaign.campaign_sends.count).to eq(0)
  end

  it "queues send when campaign has inline content" do
    campaign = workspace.campaigns.create!(
      name: "Lista",
      status: "draft",
      email_subject: "Hola",
      email_body: "Cuerpo"
    )
    segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})

    expect {
      post send_campaign_campaign_path(campaign), params: {segment_id: segment.id}
    }.to have_enqueued_job(CampaignSendJob)

    expect(response).to redirect_to(campaign)
    expect(campaign.campaign_sends.last.email_template).to be_nil
  end

  it "queues journey delivery without email content" do
    campaign = workspace.campaigns.create!(name: "Solo recorrido", status: "draft")
    segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})

    expect {
      post send_campaign_campaign_path(campaign), params: {
        segment_id: segment.id,
        delivery_mode: "journey",
        journey_id: journey.id
      }
    }.to have_enqueued_job(CampaignSendJob)

    expect(response).to redirect_to(campaign)
    send_record = campaign.campaign_sends.last
    expect(send_record.delivery_mode).to eq("journey")
    expect(send_record.journey).to eq(journey)
  end

  it "blocks journey delivery when no journey is selected" do
    campaign = workspace.campaigns.create!(name: "Sin recorrido", status: "draft")
    segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})

    post send_campaign_campaign_path(campaign), params: {
      segment_id: segment.id,
      delivery_mode: "journey"
    }

    expect(response).to redirect_to(campaign)
    expect(flash[:alert]).to include(I18n.t("flashes.campaigns.pick_active_journey"))
    expect(campaign.campaign_sends.count).to eq(0)
  end
end
