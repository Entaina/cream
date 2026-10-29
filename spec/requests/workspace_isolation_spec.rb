require "rails_helper"

RSpec.describe "Workspace isolation of submitted ids", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:other_workspace) { workspaces(:two) }
  let(:outsider) { users(:outsider) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { companies(:acme) }
  let(:foreign_company) { companies(:globex) }
  let(:foreign_person) { create_person!(other_workspace, company: foreign_company) }

  def next_task
    {"0" => {title: "Kickoff call", due_on: (Date.current + 5).to_s}}
  end

  describe "web" do
    before { sign_in_as(user) }

    describe "POST /deals" do
      def post_deal(**attrs)
        post deals_path, params: {deal: {
          name: "Isolated", company_id: company.id, pipeline_id: pipeline.id, tasks_attributes: next_task
        }.merge(attrs)}
      end

      it "rejects a company from another workspace" do
        expect { post_deal(company_id: foreign_company.id) }.not_to change(Deal, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects a partner from another workspace" do
        expect { post_deal(partner_id: foreign_company.id) }.not_to change(Deal, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects contacts from another workspace" do
        expect { post_deal(contact_ids: ["", foreign_person.id]) }.not_to change(Deal, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects an owner who is not a member of the workspace" do
        expect { post_deal(owner_id: outsider.id) }.not_to change(Deal, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects a pipeline stage from another workspace" do
        foreign_stage = Pipeline.create_default!(other_workspace).first_stage

        expect { post_deal(pipeline_stage_id: foreign_stage.id) }.not_to change(Deal, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects a product line with a product from another workspace" do
        foreign_product = other_workspace.products.create!(name: "Foreign", price: 10)

        expect {
          post_deal(deal_products_attributes: {"0" => {product_id: foreign_product.id, quantity: 1}})
        }.not_to change(DealProduct, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "keeps accepting ids from the workspace, in the submitted order" do
        first = create_person!(workspace, company: company, first_name: "Zoe")
        second = create_person!(workspace, company: company, first_name: "Ana")
        product = workspace.products.create!(name: "Plan", price: 100)

        expect {
          post_deal(contact_ids: ["", second.id, first.id], owner_id: users(:two).id, partner_id: "",
            deal_products_attributes: {"0" => {product_id: product.id, quantity: 2}})
        }.to change(Deal, :count).by(1)

        deal = Deal.order(:id).last
        expect(response).to redirect_to(deal_path(deal))
        expect(deal.contact_ids).to contain_exactly(first.id, second.id)
        expect(deal.deal_contacts.order(:id).pluck(:person_id)).to eq([second.id, first.id])
        expect(deal.owner).to eq(users(:two))
        expect(deal.partner).to be_nil
        expect(deal.deal_products.sole.product).to eq(product)
      end
    end

    describe "PATCH /deals/:id" do
      let(:deal) { create_deal!(workspace, pipeline: pipeline, company: company) }

      it "rejects moving the deal to a company from another workspace" do
        patch deal_path(deal), params: {deal: {company_id: foreign_company.id}}

        expect(response).to have_http_status(:not_found)
        expect(deal.reload.company).to eq(company)
      end

      it "still clears the owner when unassigned is chosen" do
        patch deal_path(deal), params: {deal: {owner_id: ""}}

        expect(deal.reload.owner).to be_nil
      end
    end

    describe "people" do
      let(:person) { create_person!(workspace, company: company) }

      it "rejects creating a person in a company from another workspace" do
        expect {
          post people_path, params: {person: {first_name: "Eve", company_id: foreign_company.id}}
        }.not_to change(Person, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects moving a person to a company from another workspace" do
        patch person_path(person), params: {person: {company_id: foreign_company.id}}

        expect(response).to have_http_status(:not_found)
        expect(person.reload.company).to eq(company)
      end

      it "rejects an owner who is not a member of the workspace" do
        patch person_path(person), params: {person: {owner_id: outsider.id}}

        expect(response).to have_http_status(:not_found)
        expect(person.reload.owner_id).not_to eq(outsider.id)
      end

      it "rejects a brought-by user who is not a member of the workspace" do
        patch person_path(person), params: {person: {source: "team_member", brought_by_id: outsider.id}}

        expect(response).to have_http_status(:not_found)
        expect(person.reload.brought_by_id).to be_nil
      end
    end

    describe "companies" do
      it "rejects an owner who is not a member of the workspace" do
        patch company_path(company), params: {company: {owner_id: outsider.id}}

        expect(response).to have_http_status(:not_found)
        expect(company.reload.owner_id).not_to eq(outsider.id)
      end

      it "keeps accepting members and clearing the owner" do
        patch company_path(company), params: {company: {owner_id: users(:two).id}}
        expect(company.reload.owner).to eq(users(:two))

        patch company_path(company), params: {company: {owner_id: ""}}
        expect(company.reload.owner).to be_nil
      end
    end

    describe "tasks" do
      let!(:deal) { create_deal!(workspace, pipeline: pipeline) }

      it "rejects assigning a new task to a user outside the workspace" do
        expect {
          post tasks_path, params: {
            task: {title: "Call", due_on: (Date.current + 2).to_s, assignee_id: outsider.id},
            taskable_type: "Deal", taskable_id: deal.id
          }, headers: {"HTTP_REFERER" => deal_url(deal)}
        }.not_to change(Task, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects reassigning a task to a user outside the workspace" do
        task = deal.tasks.first

        patch task_path(task), params: {task: {assignee_id: outsider.id}}, headers: {"HTTP_REFERER" => deal_url(deal)}

        expect(response).to have_http_status(:not_found)
        expect(task.reload.assignee_id).not_to eq(outsider.id)
      end
    end

    describe "POST /deals/:deal_id/line_items" do
      it "rejects a product from another workspace" do
        deal = create_deal!(workspace, pipeline: pipeline)
        foreign_product = other_workspace.products.create!(name: "Foreign", price: 10)

        expect {
          post deal_line_items_path(deal), params: {deal_product: {product_id: foreign_product.id, quantity: 1}}
        }.not_to change(DealProduct, :count)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "email templates" do
      it "rejects a layout from another workspace" do
        foreign_layout = other_workspace.email_layouts.create!(name: "Foreign", body: "<div>{{ content }}</div>")

        expect {
          post email_templates_path, params: {email_template: {
            name: "Mine", subject: "Hi", body: "<p>Hi</p>", email_layout_id: foreign_layout.id
          }}
        }.not_to change(EmailTemplate, :count)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "campaigns" do
      before do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(true)
      end

      it "rejects an email template from another workspace" do
        foreign_template = create_email_template!(other_workspace, user: users(:two))

        expect {
          post campaigns_path, params: {campaign: {name: "Marzo", status: "draft", email_template_id: foreign_template.id}}
        }.not_to change(Campaign, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects an email layout from another workspace" do
        foreign_layout = other_workspace.email_layouts.create!(name: "Foreign", body: "<div>{{ content }}</div>")

        expect {
          post campaigns_path, params: {campaign: {name: "Marzo", status: "draft", email_layout_id: foreign_layout.id}}
        }.not_to change(Campaign, :count)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "booking pages" do
      before do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
      end

      def post_booking_page(slug:, pipeline_id: nil, email_template_id: nil)
        post booking_pages_path, params: {
          booking_page: {
            name: "Agenda", slug: slug, crm_association: "none", pipeline_id: pipeline_id,
            timezone: "Europe/Madrid", booking_window_days: 60, active: true, calendar_ids: ["host-cal"],
            event_types_attributes: {
              "0" => {slug: "call", name_i18n: {es: "Llamada", en: "Call"}, duration_minutes: 30,
                      location_type: "google_meet", email_template_id: email_template_id,
                      weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json}
            }
          }
        }
      end

      it "rejects a pipeline from another workspace" do
        foreign_pipeline = Pipeline.create_default!(other_workspace)

        expect { post_booking_page(slug: "agenda-foreign-pipeline", pipeline_id: foreign_pipeline.id) }
          .not_to change(BookingPage, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects an event type email template from another workspace" do
        foreign_template = create_email_template!(other_workspace, user: users(:two))

        expect { post_booking_page(slug: "agenda-foreign-template", email_template_id: foreign_template.id) }
          .not_to change(BookingPage, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "keeps accepting an event type email template from the workspace" do
        template = create_email_template!(workspace, user: user)

        expect { post_booking_page(slug: "agenda-own-template", email_template_id: template.id) }
          .to change(BookingPage, :count).by(1)
        expect(BookingPage.find_by!(slug: "agenda-own-template").event_types.sole.email_template).to eq(template)
      end
    end
  end

  describe "API v1" do
    let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
    let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }

    it "rejects creating a deal for a company from another workspace" do
      expect {
        post "/api/v1/deals", as: :json, headers: headers, params: {deal: {
          name: "API", company_id: foreign_company.id, pipeline_id: pipeline.id,
          tasks_attributes: [{title: "Follow up", due_on: Date.current + 3}]
        }}
      }.not_to change(Deal, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "rejects moving a person to a company from another workspace" do
      person = create_person!(workspace, company: company)

      patch "/api/v1/people/#{person.id}", as: :json, headers: headers, params: {person: {company_id: foreign_company.id}}

      expect(response).to have_http_status(:not_found)
      expect(person.reload.company).to eq(company)
    end

    it "rejects assigning a task to a user outside the workspace" do
      expect {
        post "/api/v1/tasks", as: :json, headers: headers, params: {task: {
          title: "Call", due_on: Date.current + 2, assignee_id: outsider.id, taskable_type: "Company", taskable_id: company.id
        }}
      }.not_to change(Task, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "MCP" do
    let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
    let(:plaintext) { token.plaintext_token }

    it "rejects create_person with a company from another workspace" do
      result = nil
      expect {
        result = mcp_tool_error("create_person", {first_name: "Eve", company_id: foreign_company.id})
      }.not_to change(Person, :count)
      expect(result["error"]).to eq("not_found")
    end

    it "rejects update_person moving to a company from another workspace" do
      person = create_person!(workspace, company: company)

      result = mcp_tool_error("update_person", {person_id: person.id, company_id: foreign_company.id})

      expect(result["error"]).to eq("not_found")
      expect(person.reload.company).to eq(company)
    end

    it "leaves the company untouched when update_person omits it" do
      person = create_person!(workspace, company: company)

      call_tool("update_person", {person_id: person.id, job_title: "CTO"})

      expect(person.reload).to have_attributes(job_title: "CTO", company: company)
    end

    it "rejects create_deal with contacts from another workspace" do
      result = nil
      expect {
        result = mcp_tool_error("create_deal", {
          name: "MCP", company_id: company.id, person_ids: [foreign_person.id],
          next_action_title: "Call", next_action_due_on: (Date.current + 3).iso8601
        })
      }.not_to change(Deal, :count)
      expect(result["error"]).to eq("not_found")
    end

    it "rejects update_deal with a company or contacts from another workspace" do
      deal = create_deal!(workspace, pipeline: pipeline, company: company)
      contacts = deal.contact_ids

      expect(mcp_tool_error("update_deal", {deal_id: deal.id, company_id: foreign_company.id})["error"]).to eq("not_found")
      expect(mcp_tool_error("update_deal", {deal_id: deal.id, person_ids: [foreign_person.id]})["error"]).to eq("not_found")
      expect(deal.reload).to have_attributes(company: company, contact_ids: contacts)
    end
  end
end
