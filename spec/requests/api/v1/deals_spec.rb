require "rails_helper"

RSpec.describe "Api::V1::Deals", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { create_company!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }
  let(:json_headers) { headers.merge("CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json") }

  def valid_create_params(**extra)
    {
      deal: {
        name: "API Deal",
        company_id: company.id,
        pipeline_id: pipeline.id,
        pipeline_stage_id: pipeline.first_stage.id,
        tasks_attributes: [{title: "Follow up", due_on: Date.current + 3}]
      }
    }.deep_merge(extra)
  end

  describe "POST /api/v1/deals" do
    it "stores an optional execution duration in days" do
      post "/api/v1/deals",
        params: valid_create_params(deal: {execution_duration_days: 90}),
        headers: json_headers,
        as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["execution_duration_days"]).to eq(90)
      expect(workspace.deals.find(response.parsed_body["id"]).execution_duration_days).to eq(90)
    end

    it "creates a deal with product lines and edition" do
      product = workspace.products.create!(name: "Premium", price: 1200)
      edition = product.editions.create!(name: "2026")

      expect {
        post "/api/v1/deals",
          params: valid_create_params(
            deal: {
              deal_products_attributes: [
                {product_id: product.id, edition_id: edition.id, quantity: 2}
              ]
            }
          ),
          headers: json_headers,
          as: :json
      }.to change(DealProduct, :count).by(1)

      expect(response).to have_http_status(:created)
      created_deal = workspace.deals.find(response.parsed_body["id"])
      line = created_deal.deal_products.sole
      expect(line.product).to eq(product)
      expect(line.edition).to eq(edition)
      expect(created_deal.value).to eq(2400)
      expect(response.parsed_body["deal_products"]).to contain_exactly(
        include(
          "product_id" => product.id,
          "edition_id" => edition.id,
          "edition_name" => "2026",
          "quantity" => 2,
          "unit_price" => 1200.0,
          "subtotal" => 2400.0
        )
      )
    end

    it "creates a product edition from edition_name" do
      product = workspace.products.create!(name: "Premium", price: 500)

      post "/api/v1/deals",
        params: valid_create_params(
          deal: {
            deal_products_attributes: [
              {product_id: product.id, edition_name: "Madrid 2026", quantity: 1}
            ]
          }
        ),
        headers: json_headers,
        as: :json

      expect(response).to have_http_status(:created)
      line = workspace.deals.find(response.parsed_body["id"]).deal_products.sole
      expect(line.edition.name).to eq("Madrid 2026")
    end

    it "returns not found when a product id is outside the workspace" do
      outsider = workspaces(:two).products.create!(name: "Other", price: 1)

      post "/api/v1/deals",
        params: valid_create_params(
          deal: {deal_products_attributes: [{product_id: outsider.id, quantity: 1}]}
        ),
        headers: json_headers,
        as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns not found when an edition does not belong to the product" do
      product = workspace.products.create!(name: "Premium", price: 1200)
      other = workspace.products.create!(name: "Other", price: 100)
      edition = other.editions.create!(name: "2026")

      post "/api/v1/deals",
        params: valid_create_params(
          deal: {
            deal_products_attributes: [
              {product_id: product.id, edition_id: edition.id, quantity: 1}
            ]
          }
        ),
        headers: json_headers,
        as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "creates a deal with contacts" do
      contact = create_person!(workspace, company: company, first_name: "Jane", last_name: "Doe")

      post "/api/v1/deals",
        params: valid_create_params(deal: {contact_ids: [contact.id]}),
        headers: headers

      expect(response).to have_http_status(:created)
      created_deal = workspace.deals.find(response.parsed_body["id"])
      expect(created_deal.contacts).to contain_exactly(contact)
      expect(response.parsed_body["contact_ids"]).to eq([contact.id])
    end

    it "returns not found when a contact id is outside the workspace" do
      other_workspace = workspaces(:two)
      outsider = create_person!(other_workspace, first_name: "Other")

      post "/api/v1/deals",
        params: valid_create_params(deal: {contact_ids: [outsider.id]}),
        headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "creates a deal when a contact does not belong to the deal company" do
      other_company = create_company!(workspace)
      outsider = create_person!(workspace, company: other_company)

      post "/api/v1/deals",
        params: valid_create_params(deal: {contact_ids: [outsider.id]}),
        headers: headers

      expect(response).to have_http_status(:created)
      created_deal = workspace.deals.find(response.parsed_body["id"])
      expect(created_deal.contacts).to contain_exactly(outsider)
    end

    it "creates a deal with nested notes" do
      expect {
        post "/api/v1/deals",
          params: valid_create_params(notes: [{title: "Kickoff", body: "Met at conference"}]),
          headers: headers
      }.to change(Deal, :count).by(1).and change(Note, :count).by(1)

      body = response.parsed_body
      created_deal = workspace.deals.find(body["id"])
      note = created_deal.notes.sole

      expect(response).to have_http_status(:created)
      expect(body["notes"]).to contain_exactly(
        include(
          "id" => note.id,
          "title" => "Kickoff",
          "body" => "Met at conference",
          "created_at" => note.created_at.iso8601,
          "updated_at" => note.updated_at.iso8601
        )
      )
      expect(created_deal.activities.where(action: "note_added").count).to eq(1)
    end

    it "rolls back the deal when a nested note is invalid" do
      expect {
        post "/api/v1/deals",
          params: valid_create_params(notes: [{body: ""}]),
          headers: headers
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include(blank_error_for(Note, :body))
    end

    context "with nested email" do
      let(:contact) { create_person!(workspace, company: company, email: "contact@example.com") }
      let(:pdf_content) { Base64.strict_encode64("%PDF-1.4 fake report") }

      before do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
        allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)
      end

      it "creates the deal and queues SMTP delivery for the nested email" do
        expect {
          post "/api/v1/deals",
            params: valid_create_params(
              deal: {contact_ids: [contact.id]},
              email: {
                subject: "Welcome",
                body: "Thanks for joining.",
                attachments: [
                  {filename: "informe.pdf", content_type: "application/pdf", content: pdf_content}
                ]
              }
            ),
            headers: json_headers,
            as: :json
        }.to change(Deal, :count).by(1)
          .and change(EmailMessage, :count).by(1)
          .and have_enqueued_mail(RecordMailer, :tracked_email)

        created_deal = workspace.deals.find(response.parsed_body["id"])
        message = created_deal.email_messages.sole

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["email"]).to include(
          "id" => message.id,
          "to_address" => "contact@example.com",
          "subject" => "Welcome",
          "via_gmail" => false,
          "attachments" => ["informe.pdf"]
        )
        expect(message.attachments.count).to eq(1)
        expect(message.attachments.first.download).to eq("%PDF-1.4 fake report")
        expect(created_deal.activities.where(action: "email_sent").count).to eq(1)
      end

      it "queues Gmail delivery when the sender has Gmail enabled" do
        allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(true)
        workspace.gmail_connections.create!(
          user: user,
          email: "me@gmail.com",
          access_token: "at",
          refresh_token: "rt",
          expires_at: 1.hour.from_now,
          send_enabled: true,
          granted_scopes: GmailConnection::SEND_SCOPE
        )

        expect {
          post "/api/v1/deals",
            params: valid_create_params(
              deal: {contact_ids: [contact.id]},
              email: {to_address: "lead@example.com", subject: "Hi", body: "Hello"}
            ),
            headers: json_headers,
            as: :json
        }.to change(EmailMessage, :count).by(1)
          .and have_enqueued_job(SendViaGmailJob)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["email"]).to include("via_gmail" => true)
      end

      it "rolls back the deal when the nested email is invalid" do
        expect {
          post "/api/v1/deals",
            params: valid_create_params(
              email: {to_address: "bad", subject: "Hi", body: "Hello"}
            ),
            headers: json_headers,
            as: :json
        }.not_to change(Deal, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "rolls back the deal when an attachment has invalid Base64" do
        expect {
          post "/api/v1/deals",
            params: valid_create_params(
              email: {
                to_address: "lead@example.com",
                subject: "Hi",
                body: "Hello",
                attachments: [{filename: "informe.pdf", content: "not-base64!!!"}]
              }
            ),
            headers: json_headers,
            as: :json
        }.not_to change(Deal, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "creates the deal with multipart file attachments on the nested email" do
        uploaded_file = Rack::Test::UploadedFile.new(
          StringIO.new("%PDF-1.4 fake report"),
          "application/pdf",
          original_filename: "informe.pdf"
        )

        expect {
          post "/api/v1/deals",
            params: valid_create_params(
              deal: {contact_ids: [contact.id]},
              email: {
                subject: "Welcome",
                body: "Thanks for joining.",
                attachments: [uploaded_file]
              }
            ),
            headers: headers
        }.to change(Deal, :count).by(1)
          .and change(EmailMessage, :count).by(1)
          .and have_enqueued_mail(RecordMailer, :tracked_email)

        created_deal = workspace.deals.find(response.parsed_body["id"])
        message = created_deal.email_messages.sole

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["email"]["attachments"]).to eq(["informe.pdf"])
        expect(message.attachments.first.download).to eq("%PDF-1.4 fake report")
      end

      it "returns unprocessable entity when record_email is disabled" do
        allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(false)

        expect {
          post "/api/v1/deals",
            params: valid_create_params(
              email: {to_address: "lead@example.com", subject: "Hi", body: "Hello"}
            ),
            headers: json_headers,
            as: :json
        }.not_to change(Deal, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to be_present
      end
    end
  end

  describe "PATCH /api/v1/deals/:id" do
    it "routes stage changes through move_to_stage! so activity and hooks fire" do
      target = pipeline.pipeline_stages.find_by(name: "Won")

      expect {
        patch "/api/v1/deals/#{deal.id}", params: {deal: {pipeline_stage_id: target.id}}, headers: headers
      }.to change { deal.activities.where(action: "stage_changed").count }.by(1)

      expect(response).to have_http_status(:success)
      expect(deal.reload.stage_label).to eq("Won")
    end

    it "updates product lines" do
      product = workspace.products.create!(name: "Premium", price: 1000)
      edition = product.editions.create!(name: "2026")
      line = deal.deal_products.create!(product: product, edition: edition, quantity: 1)
      addon = workspace.products.create!(name: "Support", price: 200)

      patch "/api/v1/deals/#{deal.id}", params: {
        deal: {
          deal_products_attributes: [
            {id: line.id, quantity: 3},
            {product_id: addon.id, quantity: 1}
          ]
        }
      }, headers: json_headers, as: :json

      expect(response).to have_http_status(:success)
      deal.reload
      expect(deal.deal_products.count).to eq(2)
      expect(line.reload.quantity).to eq(3)
      expect(deal.value).to eq(3200)
      expect(response.parsed_body["deal_products"]).to contain_exactly(
        include("product_name" => "Premium", "quantity" => 3, "subtotal" => 3000.0),
        include("product_name" => "Support", "quantity" => 1, "subtotal" => 200.0)
      )
    end

    it "removes a product line" do
      product = workspace.products.create!(name: "Premium", price: 1000)
      line = deal.deal_products.create!(product: product, quantity: 1)

      patch "/api/v1/deals/#{deal.id}", params: {
        deal: {deal_products_attributes: [{id: line.id, _destroy: true}]}
      }, headers: json_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(deal.reload.deal_products).to be_empty
      expect(response.parsed_body["deal_products"]).to eq([])
    end

    it "updates contacts" do
      contact = create_person!(workspace, company: deal.company)

      patch "/api/v1/deals/#{deal.id}", params: {deal: {contact_ids: [contact.id]}}, headers: headers

      expect(response).to have_http_status(:success)
      expect(deal.reload.contacts).to contain_exactly(contact)
      expect(response.parsed_body["contact_ids"]).to eq([contact.id])
    end

    it "updates and clears the execution duration" do
      patch "/api/v1/deals/#{deal.id}", params: {deal: {execution_duration_days: 60}}, headers: json_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["execution_duration_days"]).to eq(60)

      patch "/api/v1/deals/#{deal.id}", params: {deal: {execution_duration_days: nil}}, headers: json_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["execution_duration_days"]).to be_nil
      expect(deal.reload.execution_duration_days).to be_nil
    end

    it "rejects a non-positive execution duration" do
      patch "/api/v1/deals/#{deal.id}", params: {deal: {execution_duration_days: 0}}, headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(deal.reload.execution_duration_days).to be_nil
    end

    it "updates execution dates and payment fields" do
      patch "/api/v1/deals/#{deal.id}",
        params: {
          deal: {
            execution_starts_on: "2026-08-01",
            execution_ends_on: "2026-10-31",
            payment_method: "deferred",
            payment_on: "2026-09-15"
          }
        },
        headers: json_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        "execution_starts_on" => "2026-08-01",
        "execution_ends_on" => "2026-10-31",
        "payment_method" => "deferred",
        "payment_on" => "2026-09-15"
      )
    end

    it "sets payment_on from execution start for cash payment" do
      patch "/api/v1/deals/#{deal.id}",
        params: {
          deal: {
            execution_starts_on: "2026-08-01",
            payment_method: "cash",
            payment_on: "2026-12-01"
          }
        },
        headers: json_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["payment_on"]).to eq("2026-08-01")
      expect(deal.reload.payment_on).to eq(Date.new(2026, 8, 1))
    end

    it "updates plain fields without logging a stage change" do
      expect {
        patch "/api/v1/deals/#{deal.id}", params: {deal: {name: "Via API"}}, headers: headers
      }.not_to change { deal.activities.where(action: "stage_changed").count }

      expect(deal.reload.name).to eq("Via API")
      expect(response.parsed_body).to include(
        "created_at" => deal.created_at.iso8601,
        "updated_at" => deal.updated_at.iso8601
      )
    end
  end

  describe "GET /api/v1/deals" do
    it "returns forbidden when the token user is no longer a workspace member" do
      member = users(:two)
      member_token = member.api_tokens.create!(name: "Ex-member", workspace: workspace)
      member_headers = {"Authorization" => "Bearer #{member_token.plaintext_token}"}
      member.memberships.find_by!(workspace: workspace).destroy!

      get "/api/v1/deals", headers: member_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq("error" => "Forbidden")
    end

    it "paginates results with limit and offset" do
      create_deal!(workspace, pipeline: pipeline, name: "First")
      create_deal!(workspace, pipeline: pipeline, name: "Second")
      create_deal!(workspace, pipeline: pipeline, name: "Third")

      get "/api/v1/deals", params: {limit: 1, offset: 1}, headers: headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.map { |row| row["id"] }
      expect(ids.size).to eq(1)
      expected_ids = policy_scope_deal_ids(workspace, user).sort
      expect(ids).to eq([expected_ids[1]])
    end

    it "caps limit at the configured maximum" do
      stub_const("Api::V1::BaseController::MAX_LIST_LIMIT", 2)
      3.times { |i| create_deal!(workspace, pipeline: pipeline, name: "Bulk #{i}") }

      get "/api/v1/deals", params: {limit: 10_000}, headers: headers

      expect(response.parsed_body.size).to eq(2)
    end
  end

  def policy_scope_deal_ids(workspace, viewer)
    Pundit.policy_scope(UserContext.new(user: viewer, workspace: workspace), workspace.deals).pluck(:id)
  end
end
