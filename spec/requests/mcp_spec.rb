require "rails_helper"

RSpec.describe "Mcp", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:plaintext) { token.plaintext_token }

  describe "POST /mcp" do
    it "returns 401 without token" do
      post mcp_url, params: initialize_payload, as: :json,
        headers: {"Accept" => "application/json"}

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include("resource_metadata=")
      expect(response.headers["WWW-Authenticate"]).to include(".well-known/oauth-protected-resource")
    end

    it "returns 401 with invalid token" do
      post mcp_url, params: initialize_payload, as: :json,
        headers: mcp_headers("cream_invalid")

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 405 for GET" do
      get mcp_url, headers: {"Authorization" => "Bearer #{plaintext}"}

      expect(response).to have_http_status(:method_not_allowed)
    end

    it "initializes with api token" do
      post mcp_url, params: initialize_payload, as: :json, headers: mcp_headers(plaintext)

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["jsonrpc"]).to eq("2.0")
      expect(body.dig("result", "serverInfo", "name")).to eq("cream")
    end

    it "returns compact server instructions under the client truncation budget" do
      post mcp_url, params: initialize_payload, as: :json, headers: mcp_headers(plaintext)

      instructions = JSON.parse(response.body).dig("result", "instructions")
      expect(instructions).to be_present
      expect(instructions.length).to be <= CreamMcp::MAX_INSTRUCTIONS_LENGTH
      expect(instructions).to include("list_my_tasks", "natural_language_search", "list_pipelines", "send_deal_email")
      expect(instructions).not_to match(/configurable stages \(/)
    end

    it "lists tools with api token" do
      post mcp_url, params: tools_list_payload, as: :json, headers: mcp_headers(plaintext)

      expect(response).to have_http_status(:success)
      tools = JSON.parse(response.body).dig("result", "tools")
      expect(tools.map { |t| t["name"] }).to include("search_records", "pipeline_summary",
        "list_custom_fields", "set_custom_fields",
        "list_products", "list_tasks", "list_my_tasks", "list_emails", "get_email", "send_deal_email", "list_activity", "list_payments", "list_pipelines",
        "list_stage_conditions", "create_stage_condition", "update_stage_condition", "delete_stage_condition",
        "update_person", "update_company", "update_deal", "add_comment",
        "list_person_duplicates", "list_company_duplicates", "merge_person", "merge_company", "delete_record",
        "create_product", "update_product", "add_deal_product", "update_deal_product", "update_task", "get_deal_history",
        "recent_changes", "sales_forecast",
        "summarize_record", "suggest_next_steps", "draft_email", "natural_language_search", "enrich_record",
        "list_mqls", "get_person_marketing", "send_campaign", "convert_mql_to_sql")
    end

    it "lists products scoped to the token workspace" do
      workspace.products.create!(name: "Widget", price: 10)
      workspaces(:two).products.create!(name: "Hidden Widget", price: 99)

      result = call_tool("list_products", {})

      names = result["products"].map { |p| p["name"] }
      expect(names).to include("Widget")
      expect(names).not_to include("Hidden Widget")
    end

    it "filters tasks by overdue status" do
      person = create_person!(workspace)
      person.tasks.create!(title: "Late", due_on: Date.current - 2, workspace: workspace, user: user, assignee: user)
      person.tasks.create!(title: "Future", due_on: Date.current + 5, workspace: workspace, user: user, assignee: user)

      result = call_tool("list_tasks", {status: "overdue"})

      titles = result["tasks"].map { |t| t["title"] }
      expect(titles).to include("Late")
      expect(titles).not_to include("Future")
    end

    it "lists my overdue and today tasks with urls" do
      person = create_person!(workspace)
      other_user = users(:two)
      workspace.memberships.find_or_create_by!(user: other_user)

      person.tasks.create!(title: "Overdue mine", due_on: Date.current - 1, workspace: workspace, user: user, assignee: user)
      person.tasks.create!(title: "Today mine", due_on: Date.current, workspace: workspace, user: user, assignee: user)
      person.tasks.create!(title: "Future mine", due_on: Date.current + 3, workspace: workspace, user: user, assignee: user)
      person.tasks.create!(title: "Overdue other", due_on: Date.current - 1, workspace: workspace, user: other_user, assignee: other_user)

      original_url = ENV["CREAM_APP_URL"]
      ENV["CREAM_APP_URL"] = "https://cream.test"
      begin
        result = call_tool("list_my_tasks", {})

        titles = result["tasks"].map { |t| t["title"] }
        expect(titles).to include("Overdue mine", "Today mine")
        expect(titles).not_to include("Future mine", "Overdue other")

        overdue_task = result["tasks"].find { |t| t["title"] == "Overdue mine" }
        expect(overdue_task["url"]).to eq("https://cream.test/people/#{person.id}")
        expect(overdue_task["overdue"]).to be(true)
      ensure
        ENV["CREAM_APP_URL"] = original_url
      end
    end

    it "respects list_my_tasks scope and limit cap" do
      person = create_person!(workspace)
      3.times do |i|
        person.tasks.create!(title: "Task #{i}", due_on: Date.current - i, workspace: workspace, user: user, assignee: user)
      end

      result = call_tool("list_my_tasks", {scope: "overdue", limit: 2})

      expect(result["tasks"].size).to eq(2)
      expect(result["tasks"].all? { |t| t["overdue"] }).to be(true)
    end

    it "filters tasks by company record_type and record_query" do
      company = companies(:acme)
      other_company = workspace.companies.create!(name: "Other Co")
      company.tasks.create!(title: "Acme task", due_on: Date.current, workspace: workspace, user: user, assignee: user)
      other_company.tasks.create!(title: "Other task", due_on: Date.current, workspace: workspace, user: user, assignee: user)

      result = call_tool("list_tasks", {record_type: "company", record_query: "Acme"})

      titles = result["tasks"].map { |t| t["title"] }
      expect(titles).to include("Acme task")
      expect(titles).not_to include("Other task")
    end

    it "includes open deal tasks when filtering by company" do
      company = companies(:acme)
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      open_deal = create_deal!(workspace, pipeline: pipeline, company: company, name: "Open opp", contacts: [])
      open_deal.tasks.create!(title: "Deal follow-up", due_on: Date.current, workspace: workspace, user: user, assignee: user)
      won_stage = pipeline.pipeline_stages.find_by(name: "Won")
      closed_deal = create_deal!(workspace, pipeline: pipeline, company: company, stage: won_stage, name: "Won opp", contacts: [])
      closed_deal.tasks.create!(title: "Won deal task", due_on: Date.current, workspace: workspace, user: user, assignee: user)
      company.tasks.create!(title: "Acme task", due_on: Date.current, workspace: workspace, user: user, assignee: user)

      result = call_tool("list_tasks", {record_type: "company", record_query: "Acme"})

      expect(result["tasks"].map { |t| t["title"] }).to include("Acme task")
      deal_titles = result["open_deal_tasks"].flat_map { |group| group["tasks"].map { |t| t["title"] } }
      expect(deal_titles).to include("Deal follow-up", "Next action")
      expect(deal_titles).not_to include("Won deal task")
      expect(result["open_deal_tasks"].first["deal"]["name"]).to eq("Open opp")
    end

    it "filters tasks by person record_type and record_id" do
      company = companies(:acme)
      person = create_person!(workspace, company: company, first_name: "Jane", last_name: "Doe")
      other_person = create_person!(workspace, company: company, first_name: "John", last_name: "Smith")
      person.tasks.create!(title: "Jane task", due_on: Date.current, workspace: workspace, user: user, assignee: user)
      other_person.tasks.create!(title: "John task", due_on: Date.current, workspace: workspace, user: user, assignee: user)

      result = call_tool("list_tasks", {record_type: "person", record_id: person.id})

      titles = result["tasks"].map { |t| t["title"] }
      expect(titles).to include("Jane task")
      expect(titles).not_to include("John task")
    end

    it "includes open deal tasks when filtering by person" do
      company = companies(:acme)
      person = create_person!(workspace, company: company, first_name: "Jane", last_name: "Doe")
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      open_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], name: "Jane opp")
      open_deal.tasks.create!(title: "Deal task for Jane", due_on: Date.current, workspace: workspace, user: user, assignee: user)
      person.tasks.create!(title: "Jane task", due_on: Date.current, workspace: workspace, user: user, assignee: user)

      result = call_tool("list_tasks", {record_type: "person", record_id: person.id})

      expect(result["tasks"].map { |t| t["title"] }).to include("Jane task")
      deal_titles = result["open_deal_tasks"].flat_map { |group| group["tasks"].map { |t| t["title"] } }
      expect(deal_titles).to include("Deal task for Jane", "Next action")
      expect(result["open_deal_tasks"].first["deal"]["name"]).to eq("Jane opp")
    end

    it "filters tasks by assignee_query for another workspace user" do
      person = create_person!(workspace)
      other_user = users(:two)
      workspace.memberships.find_or_create_by!(user: other_user)

      person.tasks.create!(title: "Mine", due_on: Date.current, workspace: workspace, user: user, assignee: user)
      person.tasks.create!(title: "Theirs", due_on: Date.current, workspace: workspace, user: other_user, assignee: other_user)

      result = call_tool("list_tasks", {assignee_query: "User Two"})

      titles = result["tasks"].map { |t| t["title"] }
      expect(titles).to include("Theirs")
      expect(titles).not_to include("Mine")
    end

    it "returns an error when record_query matches multiple companies" do
      workspace.companies.create!(name: "Acme East")
      workspace.companies.create!(name: "Acme West")

      result = call_tool("list_tasks", {record_type: "company", record_query: "Acme"})

      expect(result["error"]).to eq("invalid_argument")
      expect(result["message"]).to include("Multiple company")
    end

    it "includes urls for people, companies and deals" do
      company = companies(:acme)
      person = create_person!(workspace, company: company, first_name: "Url", last_name: "Person")
      deal = create_deal!(workspace, company: company, name: "Url Deal", contacts: [person])

      original_url = ENV["CREAM_APP_URL"]
      ENV["CREAM_APP_URL"] = "https://cream.test"
      begin
        people = call_tool("list_people", {company_id: company.id})
        person_json = people["people"].find { |p| p["id"] == person.id }
        expect(person_json["url"]).to eq("https://cream.test/people/#{person.id}")

        companies = call_tool("list_companies", {})
        company_json = companies["companies"].find { |c| c["id"] == company.id }
        expect(company_json["url"]).to eq("https://cream.test/companies/#{company.id}")

        deals = call_tool("list_deals", {query: "Url Deal"})
        deal_json = deals["deals"].first
        expect(deal_json["url"]).to eq("https://cream.test/deals/#{deal.id}")
        expect(deal_json["company_url"]).to eq("https://cream.test/companies/#{company.id}")
        expect(deal_json["contacts"].first["url"]).to eq("https://cream.test/people/#{person.id}")

        search = call_tool("search_records", {query: "Url"})
        searched_person = search["people"].find { |p| p["id"] == person.id }
        expect(searched_person["url"]).to eq("https://cream.test/people/#{person.id}")

        record = call_tool("get_record", {record_type: "deal", record_id: deal.id})
        expect(record["url"]).to eq("https://cream.test/deals/#{deal.id}")
        expect(record["contacts"].first["url"]).to eq("https://cream.test/people/#{person.id}")
      ensure
        ENV["CREAM_APP_URL"] = original_url
      end
    end

    it "lists pipelines with their stages" do
      Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)

      result = call_tool("list_pipelines", {})

      expect(result["pipelines"]).to be_present
      stage_names = result["pipelines"].flat_map { |pl| pl["stages"].map { |s| s["name"] } }
      expect(stage_names).to include("Lead")
    end

    describe "stage conditions" do
      let!(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
      let(:stage) { pipeline.pipeline_stages.find_by!(name: "Qualified") }

      it "lists stage conditions with field catalog and operators" do
        workspace.stage_conditions.create!(pipeline_stage: stage, field: "value",
          operator: "gt", compare_value: "1000")

        result = call_tool("list_stage_conditions", {stage: "Qualified"})

        expect(result["stage_conditions"].size).to eq(1)
        expect(result["stage_conditions"].first).to include("field" => "value", "stage" => "Qualified")
        expect(result["operators"]).to include("gt")
        expect(result["available_fields"]).to be_present
      end

      it "does not list conditions from another workspace" do
        other = workspaces(:two)
        other_pipeline = Pipeline.create_default!(other)
        other_stage = other_pipeline.pipeline_stages.second
        other.stage_conditions.create!(pipeline_stage: other_stage, field: "value",
          operator: "gt", compare_value: "500")

        result = call_tool("list_stage_conditions", {})

        fields = result["stage_conditions"].map { |c| c["compare_value"] }
        expect(fields).not_to include("500")
      end

      it "creates a stage condition" do
        result = call_tool("create_stage_condition", {
          stage: "Qualified", field: "value", operator: "gt", compare_value: "1000"
        })

        expect(result.dig("created", "field")).to eq("value")
        expect(result.dig("created", "stage")).to eq("Qualified")
        expect(workspace.stage_conditions.find_by(field: "value", compare_value: "1000")).to be_present
      end

      it "returns validation_error for an invalid create" do
        result = mcp_tool_error("create_stage_condition", {
          stage: "Qualified", field: "value", operator: "gt", compare_value: ""
        })

        expect(result["error"]).to eq("validation_error")
      end

      it "updates and deletes a stage condition" do
        condition = workspace.stage_conditions.create!(pipeline_stage: stage, field: "value",
          operator: "gt", compare_value: "1000")

        updated = call_tool("update_stage_condition", {id: condition.id, compare_value: "2000"})
        expect(updated.dig("updated", "compare_value")).to eq("2000")

        deleted = call_tool("delete_stage_condition", {id: condition.id})
        expect(deleted.dig("deleted", "id")).to eq(condition.id)
        expect { condition.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "returns not_found when updating a condition from another workspace" do
        other = workspaces(:two)
        other_pipeline = Pipeline.create_default!(other)
        other_stage = other_pipeline.pipeline_stages.second
        foreign = other.stage_conditions.create!(pipeline_stage: other_stage, field: "value",
          operator: "gt", compare_value: "999")

        result = mcp_tool_error("update_stage_condition", {id: foreign.id, compare_value: "1"})

        expect(result["error"]).to eq("not_found")
      end

      it "returns feature_unavailable when stage_conditions is disabled" do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:stage_conditions).and_return(false)

        result = mcp_tool_error("list_stage_conditions", {})

        expect(result["error"]).to eq("feature_unavailable")
      end
    end

    it "lists payments scoped to the token workspace" do
      connection = workspace.stripe_connections.create!(user: user, api_key: "rk_test_123")
      workspace.stripe_payments.create!(
        stripe_connection: connection,
        stripe_charge_id: "ch_mcp_one",
        amount_cents: 50_000,
        currency: "eur",
        customer_email: "mine@example.com",
        paid_at: Time.current
      )
      other_connection = workspaces(:two).stripe_connections.create!(user: users(:two), api_key: "rk_test_456")
      workspaces(:two).stripe_payments.create!(
        stripe_connection: other_connection,
        stripe_charge_id: "ch_mcp_two",
        amount_cents: 99_000,
        currency: "eur",
        customer_email: "foreign@example.com",
        paid_at: Time.current
      )

      result = call_tool("list_payments", {status: "pending_review"})

      emails = result["payments"].map { |p| p["customer_email"] }
      expect(emails).to include("mine@example.com")
      expect(emails).not_to include("foreign@example.com")
    end

    it "summarizes a record when AI is configured" do
      person = create_person!(workspace, company: companies(:acme))
      client = instance_double(Ai::Client)
      allow(Ai::Client).to receive(:new).and_return(client)
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:ai_assistant).and_return(true)
      allow(Ai::Configuration).to receive(:configured?).and_return(true)
      allow(client).to receive(:chat).and_return({
        summary: "Helpful contact",
        risks: [],
        next_steps: ["Follow up"],
        missing_data: []
      }.to_json)

      result = call_tool("summarize_record", {record_type: "person", record_id: person.id})

      expect(result["summary"]).to eq("Helpful contact")
    end

    it "returns ai_unavailable when AI is not configured" do
      person = create_person!(workspace, company: companies(:acme))
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:ai_assistant).and_return(true)
      allow(Ai::Configuration).to receive(:configured?).and_return(false)

      result = call_tool("summarize_record", {record_type: "person", record_id: person.id})

      expect(result["error"]).to eq("ai_unavailable")
    end

    it "adds a product line to a deal and recalculates its value" do
      deal = create_deal!(workspace)

      create_result = call_tool("create_product", {name: "Service", price: 100})
      product_id = create_result["created"]["id"]

      result = call_tool("add_deal_product", {deal_id: deal.id, product_id: product_id, quantity: 3})

      expect(result.dig("updated", "value")).to eq(300.0)
      expect(deal.reload.value.to_f).to eq(300.0)
    end

    it "adds a product line with an edition and exposes it on the deal" do
      deal = create_deal!(workspace)
      product_id = call_tool("create_product", {name: "Service", price: 100}).dig("created", "id")

      result = call_tool("add_deal_product",
        {deal_id: deal.id, product_id: product_id, quantity: 1, edition: "Pro"})

      line = result.dig("updated", "products").first
      expect(line["edition"]).to eq("Pro")
      expect(deal.reload.deal_products.first.edition.name).to eq("Pro")
      expect(workspace.editions.pluck(:name)).to include("Pro")
    end

    it "updates an existing product line's quantity, price and edition" do
      deal = create_deal!(workspace)
      product_id = call_tool("create_product", {name: "Service", price: 100}).dig("created", "id")
      added = call_tool("add_deal_product",
        {deal_id: deal.id, product_id: product_id, quantity: 1, edition: "Basic"})
      line_item_id = added.dig("updated", "products").first["line_item_id"]

      result = call_tool("update_deal_product",
        {deal_id: deal.id, line_item_id: line_item_id, quantity: 2, unit_price: 150, edition: "Pro"})

      line = result.dig("updated", "products").first
      expect(line["quantity"]).to eq(2)
      expect(line["unit_price"]).to eq(150.0)
      expect(line["edition"]).to eq("Pro")
      expect(result.dig("updated", "value")).to eq(300.0)
      expect(deal.reload.value.to_f).to eq(300.0)
    end

    it "clears a product line's edition when passed an empty string" do
      deal = create_deal!(workspace)
      product_id = call_tool("create_product", {name: "Service", price: 100}).dig("created", "id")
      added = call_tool("add_deal_product",
        {deal_id: deal.id, product_id: product_id, quantity: 1, edition: "Pro"})
      line_item_id = added.dig("updated", "products").first["line_item_id"]

      result = call_tool("update_deal_product",
        {deal_id: deal.id, line_item_id: line_item_id, edition: ""})

      expect(result.dig("updated", "products").first).not_to have_key("edition")
      expect(deal.reload.deal_products.first.edition).to be_nil
    end

    it "updates a person's fields" do
      person = create_person!(workspace, first_name: "Ana", job_title: "CTO")

      result = call_tool("update_person",
        {person_id: person.id, email: "ana@example.com", job_title: ""})

      expect(result.dig("updated", "email")).to eq("ana@example.com")
      person.reload
      expect(person.email).to eq("ana@example.com")
      expect(person.job_title).to be_blank
      expect(person.first_name).to eq("Ana")
    end

    it "lists person duplicate groups by email" do
      company = create_company!(workspace)
      create_person!(workspace, company: company, first_name: "Pat", email: "dup@acme.com")
      create_person!(workspace, company: company, first_name: "Patrick", email: "dup@acme.com")

      result = call_tool("list_person_duplicates", {})

      group = result["duplicate_groups"].find { |g| g["email"] == "dup@acme.com" }
      expect(group).to be_present
      expect(group["people"].map { |p| p["name"] }).to contain_exactly("Pat Doe", "Patrick Doe")
    end

    it "lists company duplicate groups by domain" do
      workspace.companies.create!(name: "Acme Inc", domain: "acme.com")
      workspace.companies.create!(name: "ACME", domain: "acme.com")

      result = call_tool("list_company_duplicates", {})

      group = result["duplicate_groups"].find do |g|
        names = g["companies"].map { |c| c["name"] }
        names.include?("Acme Inc") && names.include?("ACME")
      end
      expect(group).to be_present
      expect(group["reason"]).to include("Same domain")
    end

    it "merges duplicate people into the primary" do
      company = create_company!(workspace)
      primary = create_person!(workspace, company: company, first_name: "Primary", email: "dup@acme.com")
      secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "dup@acme.com", phone: "600111222")

      expect {
        result = call_tool("merge_person", {primary_id: primary.id, secondary_ids: [secondary.id]})
        expect(result.dig("merged", "id")).to eq(primary.id)
        expect(result["merged_ids"]).to eq([secondary.id])
      }.to change(Person, :count).by(-1)

      expect(Person.exists?(secondary.id)).to be(false)
      expect(primary.reload.phone).to eq("600111222")
    end

    it "merges duplicate companies into the primary" do
      primary = workspace.companies.create!(name: "Acme Inc", domain: "acme.com")
      secondary = workspace.companies.create!(name: "ACME", domain: "acme.com", industry: "Tech")

      expect {
        result = call_tool("merge_company", {primary_id: primary.id, secondary_ids: [secondary.id]})
        expect(result.dig("merged", "id")).to eq(primary.id)
        expect(result["merged_ids"]).to eq([secondary.id])
      }.to change(Company, :count).by(-1)

      expect(Company.exists?(secondary.id)).to be(false)
      expect(primary.reload.industry).to eq("Tech")
    end

    it "returns a merge error when no secondaries are selected" do
      person = create_person!(workspace, email: "solo@acme.com")

      result = call_tool("merge_person", {primary_id: person.id, secondary_ids: []})

      expect(result["error"]).to eq("merge_error")
      expect(result["message"]).to include(I18n.t("people.merge.errors.no_secondaries"))
    end

    it "does not merge people from another workspace" do
      primary = create_person!(workspace, email: "mine@acme.com")
      other_workspace = workspaces(:two)
      other_company = create_company!(other_workspace)
      foreign = create_person!(other_workspace, company: other_company, email: "foreign@acme.com")

      expect {
        post mcp_url,
          params: {jsonrpc: "2.0", id: 99, method: "tools/call",
                   params: {name: "merge_person",
                            arguments: {primary_id: primary.id, secondary_ids: [foreign.id]}}},
          as: :json, headers: mcp_headers(plaintext)
      }.not_to change(Person, :count)

      expect(response).to have_http_status(:success)
      parsed = JSON.parse(JSON.parse(response.body).dig("result", "content", 0, "text"))
      expect(parsed["error"]).to eq("invalid_argument")
      expect(parsed["message"]).to include("Unknown person ids")
    end

    it "deletes a person" do
      person = create_person!(workspace, first_name: "ToDelete")

      result = call_tool("delete_record", {record_type: "person", record_id: person.id})

      expect(result.dig("deleted", "type")).to eq("person")
      expect(result.dig("deleted", "id")).to eq(person.id)
      expect(Person.exists?(person.id)).to be(false)
    end

    it "deletes a deal" do
      deal = create_deal!(workspace)

      result = call_tool("delete_record", {record_type: "deal", record_id: deal.id})

      expect(result.dig("deleted", "type")).to eq("deal")
      expect(Deal.exists?(deal.id)).to be(false)
    end

    it "deletes a company and its people and deals" do
      company = create_company!(workspace, name: "Gone Co")
      person = create_person!(workspace, company: company)
      deal = create_deal!(workspace, company: company, contacts: [person])

      result = call_tool("delete_record", {record_type: "company", record_id: company.id})

      expect(result.dig("deleted", "name")).to eq("Gone Co")
      expect(Company.exists?(company.id)).to be(false)
      expect(Person.exists?(person.id)).to be(false)
      expect(Deal.exists?(deal.id)).to be(false)
    end

    it "updates a company's fields" do
      company = create_company!(workspace)

      result = call_tool("update_company",
        {company_id: company.id, industry: "Education", annual_revenue: 500_000})

      expect(result.dig("updated", "industry")).to eq("Education")
      expect(company.reload.annual_revenue).to eq(500_000)
    end

    it "exposes fiscal_information when reading companies" do
      company = create_company!(workspace, name: "Fiscal Co")
      company.update!(fiscal_information: "Example S.L.\nCIF B12345678\nIBAN ES12 3456 7890")

      list_result = call_tool("list_companies", {query: "Fiscal Co"})
      listed = list_result["companies"].find { |c| c["id"] == company.id }
      expect(listed["fiscal_information"]).to include("CIF B12345678")

      record = call_tool("get_record", {record_type: "company", record_id: company.id})
      expect(record["fiscal_information"]).to include("IBAN ES12 3456 7890")
    end

    it "creates and updates fiscal_information via MCP" do
      created = call_tool("create_company", {
        name: "New Fiscal Co",
        fiscal_information: "Razon social: New Fiscal Co\nCIF B87654321"
      })

      company_id = created.dig("created", "id")
      expect(created.dig("created", "fiscal_information")).to include("CIF B87654321")

      updated = call_tool("update_company", {
        company_id: company_id,
        fiscal_information: "Razon social: New Fiscal Co\nCIF B87654321\nIBAN ES98 7654 3210"
      })

      expect(updated.dig("updated", "fiscal_information")).to include("IBAN ES98 7654 3210")
      expect(Company.find(company_id).fiscal_information).to include("IBAN ES98 7654 3210")
    end

    it "updates a deal's fields and replaces its contacts" do
      deal = create_deal!(workspace, value: 100)
      new_contact = create_person!(workspace, company: deal.company, first_name: "Nuevo")

      result = call_tool("update_deal",
        {deal_id: deal.id, value: 900, expected_close_date: (Date.current + 30).iso8601,
         execution_duration_days: 90, person_ids: [new_contact.id]})

      expect(result.dig("updated", "value")).to eq(900.0)
      expect(result.dig("updated", "execution_duration_days")).to eq(90)
      deal.reload
      expect(deal.expected_close_date).to eq(Date.current + 30)
      expect(deal.execution_duration_days).to eq(90)
      expect(deal.contacts).to eq([new_contact])
    end

    it "moves a deal to another stage and pipeline through update_deal" do
      deal = create_deal!(workspace)
      workspace.pipelines.create!(name: "Ventas B", pipeline_stages_attributes: [
        {name: "Entrada", position: 1, workspace: workspace},
        {name: "Cierre", position: 2, workspace: workspace}
      ])

      result = call_tool("update_deal", {deal_id: deal.id, pipeline: "ventas b", stage: "Cierre"})

      expect(result.dig("updated", "pipeline")).to eq("Ventas B")
      expect(result.dig("updated", "stage")).to eq("Cierre")
      actions = deal.reload.activities.pluck(:action)
      expect(actions).to include("pipeline_changed", "stage_changed")
    end

    it "moves a deal by stage name case-insensitively via update_deal_stage" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      cobro = pipeline.pipeline_stages.create!(name: "Pendiente de Cobro", color: "golden",
        probability: 95, position: 90, workspace: workspace)
      deal = create_deal!(workspace, pipeline: pipeline, stage: cobro)
      won = pipeline.pipeline_stages.find_by!(name: "Won")

      result = call_tool("update_deal_stage", {deal_id: deal.id, stage: "won"})

      expect(result.dig("updated", "stage")).to eq("Won")
      expect(deal.reload.pipeline_stage).to eq(won)
    end

    it "returns a validation error when stage conditions block an MCP move" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      cobro = pipeline.pipeline_stages.create!(name: "Pendiente de Cobro", color: "golden",
        probability: 95, position: 90, workspace: workspace)
      won = pipeline.pipeline_stages.find_by!(name: "Won")
      workspace.stage_conditions.create!(pipeline_stage: won, field: "invoice_number",
        operator: "present", compare_value: nil)
      deal = create_deal!(workspace, pipeline: pipeline, stage: cobro)

      result = call_tool("update_deal_stage", {deal_id: deal.id, stage: "Won"})

      expect(result["error"]).to eq("validation_error")
      expect(result["message"]).to include("No se puede pasar a «Won»")
      expect(deal.reload.pipeline_stage).to eq(cobro)
    end

    it "returns not_found when the target stage name is unknown" do
      deal = create_deal!(workspace)

      result = call_tool("update_deal_stage", {deal_id: deal.id, stage: "No Existe"})

      expect(result["error"]).to eq("not_found")
      expect(result["message"]).to include("Unknown pipeline stage: No Existe")
    end

    it "adds a comment and exposes comments through get_record" do
      deal = create_deal!(workspace)

      created = call_tool("add_comment",
        {record_type: "deal", record_id: deal.id, body: "Cliente pide descuento"})

      expect(created.dig("created", "body")).to eq("Cliente pide descuento")
      expect(deal.reload.comments.count).to eq(1)

      result = call_tool("get_record", {record_type: "deal", record_id: deal.id})

      expect(result["comments"].map { |c| c["body"] }).to include("Cliente pide descuento")
    end

    it "threads a comment reply under its parent" do
      deal = create_deal!(workspace)
      parent = deal.comments.create!(workspace: workspace, user: user, body: "Primera")

      result = call_tool("add_comment",
        {record_type: "deal", record_id: deal.id, body: "Respuesta", parent_comment_id: parent.id})

      expect(result.dig("created", "parent_id")).to eq(parent.id)
      expect(parent.reload.replies.map(&:body)).to eq(["Respuesta"])
    end

    it "returns the full email body with get_email" do
      email = workspace.email_messages.create!(
        direction: "inbound", status: "received", user: user, record: companies(:acme),
        from_address: "client@example.com", to_address: "me@example.com",
        subject: "Re: proposal", body: "Nos encaja el precio. ¿Firmamos el jueves?"
      )

      result = call_tool("get_email", {email_id: email.id})

      expect(result.dig("email", "body")).to eq("Nos encaja el precio. ¿Firmamos el jueves?")
      expect(result.dig("email", "direction")).to eq("inbound")
      expect(result.dig("email", "from")).to eq("client@example.com")
    end

    it "does not expose emails from other workspaces through get_email" do
      foreign = workspaces(:two).email_messages.create!(
        direction: "outbound", status: "sent", user: users(:two), record: create_company!(workspaces(:two)),
        from_address: "them@example.com", to_address: "target@example.com",
        subject: "Secreto", body: "Confidencial"
      )

      post mcp_url,
        params: {jsonrpc: "2.0", id: 99, method: "tools/call",
                 params: {name: "get_email", arguments: {email_id: foreign.id}}},
        as: :json, headers: mcp_headers(plaintext)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Confidencial")
    end

    it "sends a deal email via send_deal_email and enqueues SMTP delivery" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      deal = create_deal!(workspace, pipeline: pipeline)
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)

      expect {
        result = call_tool("send_deal_email", {
          deal_id: deal.id,
          to_address: "lead@example.com",
          subject: "Proposal",
          body: "Here is the proposal."
        })

        expect(result.dig("sent", "to_address")).to eq("lead@example.com")
        expect(result.dig("sent", "subject")).to eq("Proposal")
        expect(result.dig("sent", "via_gmail")).to be(false)
      }.to change(EmailMessage, :count).by(1)
        .and have_enqueued_mail(RecordMailer, :tracked_email)
    end

    it "defaults send_deal_email recipient to the deal's first contact" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company, email: "contact@example.com")
      deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [contact])
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)

      result = call_tool("send_deal_email", {
        deal_id: deal.id,
        subject: "Hi",
        body: "Hello"
      })

      expect(result.dig("sent", "to_address")).to eq("contact@example.com")
    end

    it "attaches Base64 files with send_deal_email" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      deal = create_deal!(workspace, pipeline: pipeline)
      pdf_content = Base64.strict_encode64("%PDF-1.4 fake report")
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)

      result = call_tool("send_deal_email", {
        deal_id: deal.id,
        to_address: "lead@example.com",
        subject: "Tu informe",
        body: "Adjuntamos tu informe.",
        attachments: [
          {filename: "informe.pdf", content_type: "application/pdf", content: pdf_content}
        ]
      })

      message = EmailMessage.order(:id).last
      expect(message.attachments.count).to eq(1)
      expect(message.attachments.first.filename.to_s).to eq("informe.pdf")
      expect(result.dig("sent", "attachments")).to eq(["informe.pdf"])
    end

    it "returns feature_unavailable from send_deal_email when record_email is disabled" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      deal = create_deal!(workspace, pipeline: pipeline)
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(false)

      result = mcp_tool_error("send_deal_email", {
        deal_id: deal.id,
        subject: "Hi",
        body: "Hello"
      })

      expect(result["error"]).to eq("feature_unavailable")
    end

    it "returns invalid_attachment from send_deal_email for invalid Base64 content" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      deal = create_deal!(workspace, pipeline: pipeline)
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)

      expect {
        result = mcp_tool_error("send_deal_email", {
          deal_id: deal.id,
          to_address: "lead@example.com",
          subject: "Hi",
          body: "Hello",
          attachments: [{filename: "informe.pdf", content: "not-base64!!!"}]
        })

        expect(result["error"]).to eq("invalid_attachment")
      }.not_to change(EmailMessage, :count)
    end

    it "creates a deal with an optional email via create_deal" do
      Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company, email: "contact@example.com")
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)

      expect {
        result = call_tool("create_deal", {
          name: "New opp",
          company_id: company.id,
          person_ids: [contact.id],
          next_action_title: "Follow up",
          next_action_due_on: (Date.current + 7).iso8601,
          email: {
            subject: "Welcome",
            body: "Thanks for your interest."
          }
        })

        expect(result.dig("created", "name")).to eq("New opp")
        expect(result.dig("email", "to_address")).to eq("contact@example.com")
        expect(result.dig("email", "subject")).to eq("Welcome")
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_mail(RecordMailer, :tracked_email)
    end

    it "returns feature_unavailable from create_deal when email is requested but record_email is disabled" do
      company = create_company!(workspace)
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(false)

      expect {
        result = mcp_tool_error("create_deal", {
          name: "New opp",
          company_id: company.id,
          next_action_title: "Follow up",
          next_action_due_on: (Date.current + 7).iso8601,
          email: {subject: "Hi", body: "Hello"}
        })

        expect(result["error"]).to eq("feature_unavailable")
      }.not_to change(Deal, :count)
    end

    it "summarizes recent workspace changes with recent_changes" do
      deal = create_deal!(workspace, name: "Fresh deal")
      workspace.email_messages.create!(
        direction: "inbound", status: "received", user: user, record: companies(:acme),
        from_address: "client@example.com", to_address: "me@example.com",
        subject: "Re: proposal", body: "Looks good"
      )
      deal.track_activity("stage_changed", user: user, metadata: {from: "Lead", to: "Qualified"})

      result = call_tool("recent_changes", {days: 7, include_metrics: true})

      expect(result["window_days"]).to eq(7)
      expect(result["new_deals"].map { |d| d["name"] }).to include("Fresh deal")
      expect(result["inbound_emails"].map { |e| e["subject"] }).to include("Re: proposal")
      expect(result["significant_activity"].map { |a| a["action"] }).to include("stage_changed")
      expect(result.dig("metrics", "deals_created")).to be >= 1
      expect(result.dig("metrics", "inbound_emails")).to eq(1)
    end

    it "scopes recent_changes to the token workspace" do
      create_deal!(workspace, name: "Visible deal")
      other_workspace = workspaces(:two)
      create_deal!(other_workspace, name: "Hidden deal")

      result = call_tool("recent_changes", {days: 7})

      names = result["new_deals"].map { |d| d["name"] }
      expect(names).to include("Visible deal")
      expect(names).not_to include("Hidden deal")
    end

    it "respects the days window in recent_changes" do
      deal = create_deal!(workspace, name: "Old deal")
      deal.update_column(:created_at, 10.days.ago)

      result = call_tool("recent_changes", {days: 1, include_metrics: true})

      expect(result["new_deals"].map { |d| d["name"] }).not_to include("Old deal")
      expect(result.dig("metrics", "deals_created")).to eq(0)
    end

    it "returns weighted sales forecast with by_month, closing_soon and overdue" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      open_stage = pipeline.pipeline_stages.find_by!(name: "Lead")
      won_stage = pipeline.pipeline_stages.find_by!(name: "Won")

      create_deal!(workspace, name: "This month", value: 1000, probability: 50,
        expected_close_date: Date.current + 10, stage: open_stage)
      create_deal!(workspace, name: "Overdue deal", value: 500, probability: 20,
        expected_close_date: Date.current - 5, stage: open_stage)
      won_deal = create_deal!(workspace, name: "Closed won", value: 2000, stage: open_stage)
      won_deal.move_to_stage!(won_stage)

      result = call_tool("sales_forecast", {months: 3})

      expect(result.dig("totals", "open_deal_count")).to be >= 2
      expect(result.dig("totals", "weighted_pipeline_value")).to be > 0
      current_month = Date.current.strftime("%Y-%m")
      month_bucket = result["by_month"].find { |m| m["month"] == current_month }
      expect(month_bucket).to be_present
      expect(month_bucket["deal_count"]).to be >= 1
      expect(result["closing_soon"].map { |d| d["name"] }).to include("This month")
      expect(result["overdue"].map { |d| d["name"] }).to include("Overdue deal")
      expect(result.dig("won", "won_value_total")).to be >= 2000.0
    end

    it "returns deal version history and activity in a merged timeline" do
      deal = create_deal!(workspace)
      deal.update!(name: "Renamed deal")
      Note.create!(workspace: workspace, notable: deal, user: user, body: "Follow-up call notes")

      result = call_tool("get_deal_history", {deal_id: deal.id})

      expect(result.dig("deal", "id")).to eq(deal.id)
      version_entry = result["timeline"].find { |e| e["kind"] == "version" && e["event"] == "update" }
      expect(version_entry).to be_present
      expect(version_entry["changes"]).to include("name")
      activity_entry = result["timeline"].find { |e| e["kind"] == "activity" && e["action"] == "note_added" }
      expect(activity_entry).to be_present
    end

    it "exposes custom fields through get_record and set_custom_fields" do
      company = workspace.companies.create!(name: "CF Co")
      field = workspace.custom_fields.create!(record_type: "Company", name: "Tier",
        field_type: "select", options: %w[Gold Silver])

      post mcp_url,
        params: {
          jsonrpc: "2.0", id: 10, method: "tools/call",
          params: {name: "set_custom_fields", arguments: {
            record_type: "company", record_id: company.id, custom_fields: {field.key => "Gold"}
          }}
        },
        as: :json, headers: mcp_headers(plaintext)

      expect(response).to have_http_status(:success)
      expect(company.reload.custom_fields_hash[field.key]).to eq("Gold")

      post mcp_url,
        params: {
          jsonrpc: "2.0", id: 11, method: "tools/call",
          params: {name: "get_record", arguments: {record_type: "company", record_id: company.id}}
        },
        as: :json, headers: mcp_headers(plaintext)

      text = JSON.parse(response.body).dig("result", "content", 0, "text")
      expect(JSON.parse(text).dig("custom_fields", field.key)).to eq("Gold")
    end

    it "scopes tools/call to token workspace" do
      other_workspace = workspaces(:two)
      hidden_co = other_workspace.companies.create!(name: "Hidden Co")
      other_workspace.people.create!(first_name: "Hidden", last_name: "Person", owner: users(:two), company: hidden_co)

      post mcp_url,
        params: {
          jsonrpc: "2.0",
          id: 3,
          method: "tools/call",
          params: {name: "list_people", arguments: {}}
        },
        as: :json,
        headers: mcp_headers(plaintext)

      expect(response).to have_http_status(:success)
      people = JSON.parse(response.body).dig("result", "content", 0, "text")
      parsed = JSON.parse(people)
      names = parsed["people"].map { |p| p["name"] }
      expect(names).not_to include("Hidden Person")
    end

    it "returns forbidden when membership was revoked" do
      membership = user.memberships.find_by!(workspace: workspace)
      membership.delete

      post mcp_url,
        params: {
          jsonrpc: "2.0",
          id: 4,
          method: "tools/call",
          params: {name: "list_people", arguments: {}}
        },
        as: :json,
        headers: mcp_headers(plaintext)

      expect(response).to have_http_status(:success)
      text = JSON.parse(response.body).dig("result", "content", 0, "text")
      parsed = JSON.parse(text)
      expect(parsed["error"]).to eq("forbidden")
    end

    it "authenticates with doorkeeper access token" do
      app = Doorkeeper::Application.create!(
        name: "MCP test client",
        redirect_uri: "https://example.com/callback",
        confidential: false,
        scopes: "mcp"
      )
      access_token = Doorkeeper::AccessToken.create!(
        application: app,
        resource_owner_id: user.id,
        scopes: "mcp",
        expires_in: 2.hours
      )

      post mcp_url, params: initialize_payload, as: :json,
        headers: mcp_headers(access_token.plaintext_token)

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).dig("result", "serverInfo", "name")).to eq("cream")
    end
  end
end
