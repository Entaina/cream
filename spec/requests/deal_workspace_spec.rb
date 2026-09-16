require "rails_helper"

RSpec.describe "Deal workspace", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, name: "Enterprise plan") }

  before { sign_in_as(user) }

  def document = Nokogiri::HTML(response.body)

  it "starts on activity with creation forms inside closed dialogs" do
    get deal_path(deal)

    expect(response).to have_http_status(:ok)
    expect(document.at_css("#record-panel-activity")["hidden"]).to be_nil
    expect(document.at_css("#record-panel-information")["hidden"]).not_to be_nil
    expect(document.css('dialog[data-record-workspace-target="composer"][open]')).to be_empty
    expect(document.css('dialog form[action="/notes"]')).not_to be_empty
    expect(document.css("h1").map(&:text)).to include(deal.name)
    expect(document.at_css(".record-menu").text).to include(I18n.t("deals.show.duplicate"), I18n.t("deals.show.delete"))
    expect(document.at_css("#deal_stage_badge")).to be_present
    expect(document.at_css("#deal_stage_stepper")).to be_present
  end

  it "shows pending tasks by urgency and keeps completed tasks collapsed" do
    future = deal.tasks.create!(workspace: workspace, user: user, title: "Future task", due_on: Date.current + 4)
    overdue = deal.tasks.create!(workspace: workspace, user: user, title: "Overdue task", due_on: Date.current - 2)
    deal.tasks.create!(workspace: workspace, user: user, title: "Finished task", completed_at: Time.current)

    get deal_path(deal)

    panel = document.at_css("#record-panel-activity")
    expect(panel.text.index(overdue.title)).to be < panel.text.index(future.title)
    completed = panel.css("details").find { |details| details.at_css("summary")&.text&.include?(I18n.t("records.completed_tasks", count: 1)) }
    expect(completed["open"]).to be_nil
    expect(completed.text).to include("Finished task")
  end

  it "renders the selected section on a direct visit and defaults invalid tabs to activity" do
    get deal_path(deal, tab: "information")
    expect(document.at_css("#record-panel-information")["hidden"]).to be_nil
    expect(document.at_css("#record-tab-information")["aria-selected"]).to eq("true")

    get deal_path(deal, tab: "unknown")
    expect(document.at_css("#record-panel-activity")["hidden"]).to be_nil
  end

  it "shows pipeline and products tabs" do
    get deal_path(deal, tab: "pipeline")
    expect(document.at_css("#record-panel-pipeline")["hidden"]).to be_nil
    expect(document.at_css("#deal_stage_stepper")).to be_present

    get deal_path(deal, tab: "products")
    expect(document.at_css("#record-panel-products")["hidden"]).to be_nil
  end

  it "edits a single block without replacing the rest of the deal" do
    get edit_deal_path(deal, section: "management")
    expect(document.at_css('[name="deal[owner_id]"]')).to be_present
    expect(document.at_css('[name="deal[name]"]')).to be_nil

    patch deal_path(deal), params: {section: "management", deal: {owner_id: users(:two).id}}
    expect(response).to redirect_to(deal_path(deal, tab: "information"))
    expect(deal.reload.owner).to eq(users(:two))
    expect(deal.name).to eq("Enterprise plan")
  end

  it "keeps the overview block and submitted values when validation fails" do
    patch deal_path(deal), params: {section: "overview", deal: {name: "", invoice_number: "FAC-TEST"}}

    expect(response).to have_http_status(:unprocessable_content)
    expect(document.at_css('[role="alert"]').text).to include(blank_error_for(Deal, :name))
    expect(document.at_css('[name="deal[invoice_number]"]')["value"]).to eq("FAC-TEST")
    expect(document.at_css('[name="deal[owner_id]"]')).to be_nil
  end

  it "omits optional tabs and composers when their features are disabled" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    %i[attachments comments record_email].each { |flag| allow(CreamFeatures).to receive(:enabled?).with(flag).and_return(false) }

    get deal_path(deal, tab: "files")

    expect(document.at_css("#record-tab-files")).to be_nil
    expect(document.at_css('dialog[data-composer="email"]')).to be_nil
    expect(document.at_css('dialog[data-composer="comment"]')).to be_nil
    expect(document.at_css("#record-panel-activity")["hidden"]).to be_nil
  end
end
