require "rails_helper"

RSpec.describe "Api::V1 as an AI salesperson", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:ai_user) { users(:outsider) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { companies(:acme) }
  let!(:own_deal) { create_deal!(workspace, pipeline: pipeline, company: company, owner: ai_user, name: "Own deal") }
  let!(:other_deal) { create_deal!(workspace, pipeline: pipeline, company: company, owner: admin, name: "Other deal") }
  let(:token) { ai_user.api_tokens.create!(name: "AI", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }
  let(:json_headers) { headers.merge("CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json") }

  before { Membership.create!(user: ai_user, workspace: workspace, role: "ai_salesperson") }

  it "lists only its own deals" do
    get "/api/v1/deals", headers: headers

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.pluck("id")).to eq([own_deal.id])
  end

  it "cannot read deals owned by others" do
    get "/api/v1/deals/#{other_deal.id}", headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it "cannot delete its own deals, people, companies or tasks" do
    person = create_person!(workspace)
    task = own_deal.tasks.create!(title: "T", due_on: Date.current, workspace: workspace, user: ai_user, assignee: ai_user)

    expect { delete "/api/v1/deals/#{own_deal.id}", headers: headers }.not_to change(Deal, :count)
    expect(response).to have_http_status(:forbidden)
    expect { delete "/api/v1/people/#{person.id}", headers: headers }.not_to change(Person, :count)
    expect { delete "/api/v1/companies/#{company.id}", headers: headers }.not_to change(Company, :count)
    expect { delete "/api/v1/tasks/#{task.id}", headers: headers }.not_to change(Task, :count)
  end

  it "ignores _destroy on product lines" do
    product = workspace.products.create!(name: "Curso", price: 10)
    line = own_deal.deal_products.create!(product: product, quantity: 1, unit_price: 10)

    expect {
      patch "/api/v1/deals/#{own_deal.id}",
        params: {deal: {deal_products_attributes: [{id: line.id, _destroy: true}]}},
        headers: json_headers, as: :json
    }.not_to change(DealProduct, :count)
  end

  it "cannot unlink contacts from a deal" do
    existing = create_person!(workspace, company: company, first_name: "Existente")
    added = create_person!(workspace, company: company, first_name: "Nuevo")
    own_deal.update!(contact_ids: [existing.id])

    patch "/api/v1/deals/#{own_deal.id}", params: {deal: {contact_ids: [added.id]}},
      headers: json_headers, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(own_deal.reload.contacts).to eq([existing])
  end

  it "does not expose other people's deals through the Gmail thread status" do
    person = create_person!(workspace, company: company, email: "client@example.com")
    other_deal.update!(contact_ids: [person.id])
    own_deal.update!(contact_ids: [person.id])
    workspace.email_messages.create!(
      user: admin, record: other_deal, direction: "inbound", status: "received",
      from_address: "client@example.com", to_address: admin.email_address,
      subject: "Hi", body: "Hi", gmail_thread_id: "thread-x", rfc822_message_id: "<x@mail.example.com>"
    )

    post "/api/v1/gmail/threads/status",
      params: {gmail_thread_id: "thread-x", rfc822_message_ids: ["<x@mail.example.com>"],
               participant_emails: ["client@example.com"]},
      headers: json_headers, as: :json

    expect(response).to have_http_status(:success)
    deals = response.parsed_body.values_at("linked", "suggestions").flatten.pluck("id")
    expect(deals).to include(own_deal.id)
    expect(deals).not_to include(other_deal.id)
  end
end
