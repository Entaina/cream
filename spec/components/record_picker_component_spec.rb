# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecordPickerComponent, type: :component do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }
  let(:person) { Person.new(company: company, workspace: workspace) }

  def render_component(**options)
    controller = ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    form = ActionView::Helpers::FormBuilder.new(:person, person, controller.view_context, {})
    defaults = {
      form: form,
      attribute: :company_id,
      label: "Company",
      scope: workspace.companies.order(:name),
      search_url: "/companies/picker.json"
    }
    render_inline(RecordPickerComponent.new(**defaults, **options))
  end

  it "embeds records inline when under the limit" do
    render_component(
      create_url: "/companies.json",
      create_param: "company",
      selected_name: company.name
    )

    expect(page).to have_css('[data-controller="record-picker"]')
    expect(page).to have_css('[data-record-picker-records-value]')
    expect(page).to have_css('[data-record-picker-create-url-value="/companies.json"]')
    expect(page).to have_css('input[data-record-picker-target="input"][value="Acme Corp"]')
    expect(rendered_content).to include('name="person[company_id]"')
    expect(rendered_content).to include('data-record-picker-target="hidden"')
  end

  it "omits inline records when over the limit" do
    stub_const("RecordPickerComponent::INLINE_LIMIT", 0)

    render_component

    expect(page).to have_css('[data-record-picker-search-url-value="/companies/picker.json"]')
    expect(page).not_to have_css("[data-record-picker-records-value]")
  end

  it "omits create attributes when create is disabled" do
    render_component(create_url: nil, create_param: nil)

    expect(page).not_to have_css("[data-record-picker-create-url-value]")
    expect(page).not_to have_css("[data-record-picker-create-param-value]")
  end
end
