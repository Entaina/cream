require "rails_helper"

RSpec.describe "Sales briefings", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    sign_in_as(member)
    workspace.update!(sales_director_enabled: true)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:sales_director).and_return(true)
    allow(Ai::Configuration).to receive(:configured?).and_return(true)
  end

  it "enqueues a briefing generation job" do
    expect {
      post sales_briefing_path
    }.to have_enqueued_job(SalesDirectorBriefingJob).with(workspace.id)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include(I18n.t("flashes.sales_briefings.generating"))
  end

  it "redirects when AI is not configured" do
    allow(Ai::Configuration).to receive(:configured?).and_return(false)

    expect {
      post sales_briefing_path
    }.not_to have_enqueued_job(SalesDirectorBriefingJob)

    expect(response).to redirect_to(root_path)
  end

  it "redirects when sales director is disabled for the workspace" do
    workspace.update!(sales_director_enabled: false)

    expect {
      post sales_briefing_path
    }.not_to have_enqueued_job(SalesDirectorBriefingJob)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include(I18n.t("flashes.sales_briefings.not_enabled"))
  end

  it "redirects when the user disabled the briefing in profile" do
    memberships(:one_one).update!(sales_director_briefing_enabled: false)

    expect {
      post sales_briefing_path
    }.not_to have_enqueued_job(SalesDirectorBriefingJob)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include(I18n.t("flashes.sales_briefings.disabled_for_user"))
  end

  it "allows regeneration when a briefing already exists" do
    workspace.sales_briefings.create!(
      briefing_date: Date.current,
      summary: "Briefing existente",
      items: [{"priority" => "urgent", "text" => "Llamar a ACME"}],
      wins: [],
      misses: [],
      generated_at: Time.current
    )

    expect {
      post sales_briefing_path
    }.to have_enqueued_job(SalesDirectorBriefingJob).with(workspace.id)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include(I18n.t("flashes.sales_briefings.regenerating"))
    expect(memberships(:one_one).reload.sales_briefing_regenerations_today).to eq(1)
  end

  it "does not increment the counter on the first manual generation" do
    expect {
      post sales_briefing_path
    }.to have_enqueued_job(SalesDirectorBriefingJob).with(workspace.id)

    expect(memberships(:one_one).reload.sales_briefing_regenerations_today).to eq(0)
  end

  it "blocks regeneration after 5 attempts in the same day" do
    workspace.sales_briefings.create!(
      briefing_date: Date.current,
      summary: "Briefing existente",
      items: [{"priority" => "urgent", "text" => "Llamar a ACME"}],
      wins: [],
      misses: [],
      generated_at: Time.current
    )
    memberships(:one_one).update!(
      sales_briefing_regenerations_count: 5,
      sales_briefing_regenerations_on: Date.current
    )

    expect {
      post sales_briefing_path
    }.not_to have_enqueued_job(SalesDirectorBriefingJob)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include(I18n.t("flashes.sales_briefings.daily_limit"))
  end
end
