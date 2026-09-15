require "rails_helper"

RSpec.describe SavedView do
  fixtures :users, :workspaces, :memberships, :saved_views, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:member) { users(:two) }

  describe "validations" do
    it "requires a name and valid record type" do
      view = described_class.new(workspace: workspace, user: user, record_type: "Invalid", name: "")

      expect(view).not_to be_valid
      expect(view.errors[:name]).to be_present
      expect(view.errors[:record_type]).to be_present
    end
  end

  describe ".visible_to" do
    it "returns personal and shared views for the user" do
      visible = described_class.visible_to(user).where(workspace: workspace)

      expect(visible).to include(saved_views(:person_gold), saved_views(:person_shared))
      expect(visible).not_to include(saved_views(:member_private))
    end

    it "includes another user's private views for that user" do
      visible = described_class.visible_to(member).where(workspace: workspace)

      expect(visible).to include(saved_views(:member_private), saved_views(:person_shared))
      expect(visible).not_to include(saved_views(:person_gold))
    end
  end

  describe ".ordered" do
    it "orders by position then name within a workspace" do
      names = described_class.where(workspace: workspace).for_type("Person").ordered.pluck(:name)

      expect(names).to eq(["Gold tier", "All at Acme", "Member private"])
    end
  end

  describe "#resolve" do
    it "applies the native filter to a base scope" do
      acme = companies(:acme)
      other = create_company!(workspace, name: "Globex Local")
      at_acme = create_person!(workspace, company: acme)
      create_person!(workspace, company: other)

      resolved = saved_views(:person_shared).resolve(workspace.people)

      expect(resolved).to contain_exactly(at_acme)
    end

    it "returns the full scope when the view has no filters" do
      create_person!(workspace, company: companies(:acme))

      resolved = saved_views(:member_private).resolve(workspace.people)

      expect(resolved).to match_array(workspace.people)
    end
  end

  describe "#to_filter_hash" do
    it "includes filters, sort and direction" do
      view = saved_views(:person_gold)

      expect(view.to_filter_hash).to include("cf" => {"customer_tier" => "Gold"}, "sort" => "first_name", "dir" => "asc")
    end
  end

  describe "#records_path" do
    it "routes deal views to the board by default" do
      view = described_class.new(record_type: "Deal", id: 42)

      expect(view.records_path).to eq("/deals/board?view=42")
    end

    it "routes deal views to the table when surface=table" do
      view = described_class.new(record_type: "Deal", id: 42)

      expect(view.records_path(surface: "table")).to eq("/deals?view=42")
    end
  end

  describe ".build_from_request" do
    it "captures current filter params" do
      view = described_class.build_from_request(
        workspace: workspace,
        user: user,
        record_type: "Person",
        name: "Acme people",
        shared: false,
        params: ActionController::Parameters.new(q: "ann", company_id: companies(:acme).id.to_s, dir: "desc")
      )

      expect(view.filters).to eq("q" => "ann", "company_id" => companies(:acme).id.to_s)
      expect(view.direction).to eq("desc")
      expect(view.position).to eq(described_class.next_position_for(workspace, "Person"))
    end

    it "defaults shared to false when omitted" do
      view = described_class.build_from_request(
        workspace: workspace,
        user: user,
        record_type: "Person",
        name: "Private by default",
        shared: nil,
        params: ActionController::Parameters.new(company_id: companies(:acme).id.to_s)
      )

      expect(view.shared).to be false
      expect(view).to be_valid
    end

    it "captures deal extra filter params" do
      view = described_class.build_from_request(
        workspace: workspace,
        user: user,
        record_type: "Deal",
        name: "Filtered deals",
        shared: false,
        params: ActionController::Parameters.new(
          stage: "1",
          product_id: "2",
          edition_id: "3",
          first_contact_from: "2026-01-01",
          first_contact_to: "2026-02-01"
        )
      )

      expect(view.filters).to eq(
        "stage" => "1",
        "product_id" => "2",
        "edition_id" => "3",
        "first_contact_from" => "2026-01-01",
        "first_contact_to" => "2026-02-01"
      )
    end

    it "captures person owner filter params" do
      view = described_class.build_from_request(
        workspace: workspace,
        user: user,
        record_type: "Person",
        name: "My people",
        shared: false,
        params: ActionController::Parameters.new(owner_id: user.id.to_s)
      )

      expect(view.filters).to eq("owner_id" => user.id.to_s)
    end
  end

  describe "#resolve for Person owner filter" do
    it "filters people by owner_id" do
      company = create_company!(workspace)
      owned = create_person!(workspace, company: company, owner: user)
      create_person!(workspace, company: company, owner: users(:two))

      view = described_class.create!(
        workspace: workspace,
        user: user,
        record_type: "Person",
        name: "Owned by me",
        filters: {"owner_id" => user.id.to_s}
      )

      expect(view.resolve(workspace.people)).to contain_exactly(owned)
    end
  end

  describe "#resolve for Deal extra filters" do
    let!(:pipeline) { Pipeline.create_default!(workspace) }
    let(:company) { create_company!(workspace) }
    let(:product) { workspace.products.create!(name: "Premium", price: 100) }
    let(:edition) { product.editions.create!(name: "2026") }

    it "applies product, edition and first contact filters" do
      contact = create_person!(workspace, company: company, first_contact_on: Date.new(2026, 1, 10))
      match = create_deal!(workspace, pipeline: pipeline, name: "Match", company: company, contacts: [contact])
      match.deal_products.create!(product: product, edition: edition, quantity: 1)
      create_deal!(workspace, pipeline: pipeline, name: "Other", company: company)

      view = described_class.create!(
        workspace: workspace,
        user: user,
        record_type: "Deal",
        name: "Product view",
        filters: {
          "product_id" => product.id.to_s,
          "edition_id" => edition.id.to_s,
          "first_contact_from" => "2026-01-01",
          "first_contact_to" => "2026-01-31"
        }
      )

      resolved = view.resolve(workspace.deals)

      expect(resolved).to contain_exactly(match)
    end
  end
end
