require "rails_helper"

RSpec.describe "Person workspace", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, first_name: "Ada", last_name: "Lovelace") }

  before { sign_in_as(user) }

  def document = Nokogiri::HTML(response.body)

  it "starts on activity with creation forms inside closed dialogs" do
    get person_path(person)

    expect(response).to have_http_status(:ok)
    expect(document.at_css("#record-panel-activity")["hidden"]).to be_nil
    expect(document.at_css("#record-panel-information")["hidden"]).not_to be_nil
    expect(document.css('dialog[data-record-workspace-target="composer"][open]')).to be_empty
    expect(document.css('dialog form[action="/notes"]')).not_to be_empty
    expect(document.css("h1").map(&:text)).to include(person.display_name)
    expect(document.at_css(".record-menu").text).to include(I18n.t("people.show.merge"), I18n.t("people.show.delete"))
  end

  it "shows pending tasks by urgency and keeps completed tasks collapsed" do
    future = person.tasks.create!(workspace: workspace, user: user, title: "Future task", due_on: Date.current + 4)
    overdue = person.tasks.create!(workspace: workspace, user: user, title: "Overdue task", due_on: Date.current - 2)
    person.tasks.create!(workspace: workspace, user: user, title: "Finished task", completed_at: Time.current)

    get person_path(person)

    panel = document.at_css("#record-panel-activity")
    expect(panel.text.index(overdue.title)).to be < panel.text.index(future.title)
    completed = panel.css("details").find { |details| details.at_css("summary")&.text&.include?(I18n.t("records.completed_tasks", count: 1)) }
    expect(completed["open"]).to be_nil
    expect(completed.text).to include("Finished task")
  end

  it "renders the selected section on a direct visit and defaults invalid tabs to activity" do
    get person_path(person, tab: "information")
    expect(document.at_css("#record-panel-information")["hidden"]).to be_nil
    expect(document.at_css("#record-tab-information")["aria-selected"]).to eq("true")

    get person_path(person, tab: "unknown")
    expect(document.at_css("#record-panel-activity")["hidden"]).to be_nil
  end

  it "edits a single block without replacing the rest of the contact" do
    get edit_person_path(person, section: "management")
    expect(document.at_css('[name="person[owner_id]"]')).to be_present
    expect(document.at_css('[name="person[first_name]"]')).to be_nil

    patch person_path(person), params: {section: "management", person: {owner_id: users(:two).id}}
    expect(response).to redirect_to(person_path(person, tab: "information"))
    expect(person.reload.owner).to eq(users(:two))
    expect(person.first_name).to eq("Ada")
  end

  it "shows and edits the notes block on the information tab" do
    get person_path(person, tab: "information")
    expect(document.at_css("#record-panel-information").text).to include(I18n.t("people.show.no_notes"))

    get edit_person_path(person, section: "internal_notes")
    expect(document.at_css('textarea[name="person[internal_notes]"]')).to be_present
    expect(document.at_css('[name="person[first_name]"]')).to be_nil

    patch person_path(person), params: {section: "internal_notes", person: {internal_notes: "Prefiere llamadas por la tarde"}}
    expect(response).to redirect_to(person_path(person, tab: "information"))
    expect(person.reload.internal_notes).to eq("Prefiere llamadas por la tarde")
    expect(person.first_name).to eq("Ada")

    get person_path(person, tab: "information")
    expect(document.at_css("#record-panel-information").text).to include("Prefiere llamadas por la tarde")
  end

  it "shows the consent evidence registered through the API on the information tab" do
    person.update!(email: "ada@example.com")
    type = SubscriptionType.ensure_defaults!(workspace) && workspace.subscription_types.active.first
    Marketing::ConsentService.subscribe!(
      person: person, subscription_type: type, source: "api", legal_basis: "consent",
      metadata: {"marketing_consent_text" => "I accept emails", "consent_source" => "Partner signup form",
                 "consent_ip" => "203.0.113.7", "recorded_by" => user.name}
    )

    get person_path(person, tab: "information")

    panel = document.at_css("#record-panel-information").text
    expect(panel).to include(I18n.t("people.show.view_consent"), "I accept emails", "Partner signup form", "203.0.113.7")
  end

  it "keeps the block and submitted values when validation fails" do
    patch person_path(person), params: {section: "contact", person: {first_name: "", last_name: "", phone: "123456"}}

    expect(response).to have_http_status(:unprocessable_content)
    expect(document.at_css('[role="alert"]').text).to include(blank_error_for(Person, :first_name))
    expect(document.at_css('[name="person[phone]"]')["value"]).to eq("123456")
    expect(document.at_css('[name="person[owner_id]"]')).to be_nil
  end

  it "omits optional tabs and composers when their features are disabled" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    %i[attachments comments record_email].each { |flag| allow(CreamFeatures).to receive(:enabled?).with(flag).and_return(false) }

    get person_path(person, tab: "files")

    expect(document.at_css("#record-tab-files")).to be_nil
    expect(document.at_css('dialog[data-composer="email"]')).to be_nil
    expect(document.at_css('dialog[data-composer="comment"]')).to be_nil
    expect(document.at_css("#record-panel-activity")["hidden"]).to be_nil
  end
end
