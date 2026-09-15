require "rails_helper"

RSpec.describe "Company workspace", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:company) { create_company!(workspace, name: "Acme Corp") }

  before { sign_in_as(user) }

  def document = Nokogiri::HTML(response.body)

  it "renders a company with a domain without crashing" do
    company.update!(domain: "acme.com")

    get company_path(company)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('a[href="https://acme.com"]').text).to include("acme.com")
  end

  it "starts on activity with creation forms inside closed dialogs" do
    get company_path(company)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('#record-panel-activity')['hidden']).to be_nil
    expect(document.at_css('#record-panel-information')['hidden']).not_to be_nil
    expect(document.css('dialog[data-record-workspace-target="composer"][open]')).to be_empty
    expect(document.css('dialog form[action="/notes"]')).not_to be_empty
    expect(document.css('h1').map(&:text)).to include(company.name)
    expect(document.at_css('.record-menu').text).to include("Merge duplicates", "Delete company")
  end

  it "shows pending tasks by urgency and keeps completed tasks collapsed" do
    future = company.tasks.create!(workspace: workspace, user: user, title: "Future task", due_on: Date.current + 4)
    overdue = company.tasks.create!(workspace: workspace, user: user, title: "Overdue task", due_on: Date.current - 2)
    company.tasks.create!(workspace: workspace, user: user, title: "Finished task", completed_at: Time.current)

    get company_path(company)

    panel = document.at_css('#record-panel-activity')
    expect(panel.text.index(overdue.title)).to be < panel.text.index(future.title)
    completed = panel.css('details').find { |details| details.at_css('summary')&.text&.include?("Completed tasks") }
    expect(completed['open']).to be_nil
    expect(completed.text).to include("Finished task")
  end

  it "renders the selected section on a direct visit and defaults invalid tabs to activity" do
    get company_path(company, tab: "information")
    expect(document.at_css('#record-panel-information')['hidden']).to be_nil
    expect(document.at_css('#record-tab-information')['aria-selected']).to eq("true")

    get company_path(company, tab: "unknown")
    expect(document.at_css('#record-panel-activity')['hidden']).to be_nil
  end

  it "shows people and deals tabs with counts" do
    person = create_person!(workspace, company: company)
    create_deal!(workspace, company: company, name: "Big deal")

    get company_path(company, tab: "people")

    expect(document.at_css('#record-panel-people')['hidden']).to be_nil
    expect(document.at_css('#record-panel-people').text).to include(person.display_name)

    get company_path(company, tab: "deals")
    expect(document.at_css('#record-panel-deals')['hidden']).to be_nil
    expect(document.at_css('#record-panel-deals').text).to include("Big deal")
  end

  it "edits a single block without replacing the rest of the company" do
    get edit_company_path(company, section: "management")
    expect(document.at_css('[name="company[owner_id]"]')).to be_present
    expect(document.at_css('[name="company[name]"]')).to be_nil

    patch company_path(company), params: { section: "management", company: { owner_id: users(:two).id } }
    expect(response).to redirect_to(company_path(company, tab: "information"))
    expect(company.reload.owner).to eq(users(:two))
    expect(company.name).to eq("Acme Corp")
  end

  it "keeps the block and submitted values when validation fails" do
    patch company_path(company), params: { section: "profile", company: { name: "", domain: "acme.com" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(document.at_css('[role="alert"]').text).to include("Name")
    expect(document.at_css('[name="company[domain]"]')['value']).to eq("acme.com")
    expect(document.at_css('[name="company[owner_id]"]')).to be_nil
  end

  it "omits optional tabs and composers when their features are disabled" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    %i[attachments comments record_email].each { |flag| allow(CreamFeatures).to receive(:enabled?).with(flag).and_return(false) }

    get company_path(company, tab: "files")

    expect(document.at_css('#record-tab-files')).to be_nil
    expect(document.at_css('dialog[data-composer="email"]')).to be_nil
    expect(document.at_css('dialog[data-composer="comment"]')).to be_nil
    expect(document.at_css('#record-panel-activity')['hidden']).to be_nil
  end
end
