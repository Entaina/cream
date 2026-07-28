require "rails_helper"

RSpec.describe "Stripe payments", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:connection) do
    workspace.stripe_connections.create!(user: user, api_key: "rk_test_123")
  end

  def create_payment!(workspace_override = workspace, **attrs)
    conn = workspace_override == workspace ? connection :
      workspace_override.stripe_connections.create!(user: users(:two), api_key: "rk_test_456")
    workspace_override.stripe_payments.create!({
      stripe_connection: conn,
      stripe_charge_id: "ch_#{SecureRandom.hex(4)}",
      amount_cents: 50_000,
      currency: "eur",
      customer_email: "pat@example.com",
      paid_at: Time.current
    }.merge(attrs))
  end

  describe "GET /stripe_payments" do
    it "lists only the current workspace's payments for the selected tab" do
      create_payment!(customer_email: "mine@example.com")
      create_payment!(status: "ignored", customer_email: "ignored@example.com")
      create_payment!(workspaces(:two), customer_email: "foreign@example.com")
      sign_in_as(user)

      get stripe_payments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("mine@example.com")
      expect(response.body).not_to include("ignored@example.com")
      expect(response.body).not_to include("foreign@example.com")

      get stripe_payments_path(status: "ignored")
      expect(response.body).to include("ignored@example.com")
    end
  end

  describe "GET /stripe_payments/:id" do
    it "renders the payment detail with payload-derived info" do
      payment = create_payment!(payload: {
        "id" => "ch_x", "receipt_url" => "https://pay.stripe.com/receipts/xyz",
        "payment_method_details" => { "type" => "card", "card" => { "brand" => "visa", "last4" => "4242" } },
        "metadata" => {}
      }, metadata: { "pedido" => "A-17" })
      sign_in_as(user)

      get stripe_payment_path(payment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visa ···4242")
      expect(response.body).to include("https://pay.stripe.com/receipts/xyz")
      expect(response.body).to include("A-17")
    end

    it "404s for a payment of another workspace" do
      payment = create_payment!(workspaces(:two))
      sign_in_as(user)

      get stripe_payment_path(payment)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /stripe_payments/:id/match" do
    it "links the suggested deal and records the activity" do
      deal = create_deal!(workspace)
      payment = create_payment!(suggested_deal: deal, match_confidence: "high")
      sign_in_as(user)

      post match_stripe_payment_path(payment)

      expect(payment.reload).to be_matched
      expect(payment.deal).to eq(deal)
      expect(deal.activities.where(action: "payment_received")).to exist
    end

    it "accepts an explicit deal_id from the workspace" do
      deal = create_deal!(workspace)
      payment = create_payment!
      sign_in_as(user)

      post match_stripe_payment_path(payment, deal_id: deal.id)

      expect(payment.reload.deal).to eq(deal)
    end

    it "rejects a deal from another workspace" do
      Pipeline.create_default!(workspaces(:two))
      foreign_deal = create_deal!(workspaces(:two))
      payment = create_payment!
      sign_in_as(user)

      post match_stripe_payment_path(payment, deal_id: foreign_deal.id)

      expect(payment.reload).to be_pending_review
      expect(flash[:alert]).to be_present
    end

    it "404s for a payment of another workspace" do
      payment = create_payment!(workspaces(:two))
      sign_in_as(user)

      post match_stripe_payment_path(payment)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /stripe_payments/:id/ignore and unignore" do
    it "flips the status" do
      payment = create_payment!
      sign_in_as(user)

      post ignore_stripe_payment_path(payment)
      expect(payment.reload).to be_ignored

      post unignore_stripe_payment_path(payment)
      expect(payment.reload).to be_pending_review
    end
  end

  describe "create deal from a payment" do
    it "links the payment after saving the deal" do
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "pat@example.com")
      payment = create_payment!(suggested_person: person)
      sign_in_as(user)

      post deals_path, params: {
        stripe_payment_id: payment.id,
        deal: {
          name: "From payment", company_id: company.id, contact_ids: [ person.id ],
          pipeline_id: pipeline.id, pipeline_stage_id: pipeline.first_stage.id,
          tasks_attributes: [ { title: "Follow up", due_on: Date.current + 3 } ]
        }
      }

      deal = workspace.deals.find_by!(name: "From payment")
      expect(payment.reload).to be_matched
      expect(payment.deal).to eq(deal)
    end
  end
end
