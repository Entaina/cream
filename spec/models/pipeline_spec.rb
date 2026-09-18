require "rails_helper"

RSpec.describe Pipeline, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  describe ".create_default!" do
    it "creates the Ventas pipeline with the default sales stages" do
      pipeline = Pipeline.create_default!(workspace)

      expect(pipeline.name).to eq("Ventas")
      expect(pipeline).to be_default_pipeline
      expect(pipeline.pipeline_stages.ordered.map(&:name)).to eq(%w[Lead Qualified Proposal Negotiation Won Lost])
      expect(pipeline.pipeline_stages.find_by(name: "Won")).to have_attributes(won: true, closed: true, probability: 100)
      expect(pipeline.pipeline_stages.find_by(name: "Lead")).to have_attributes(won: false, closed: false, probability: 10)
    end
  end

  describe ".default_for" do
    it "returns the pipeline flagged as default" do
      Pipeline.create_default!(workspace)
      expect(Pipeline.default_for(workspace).name).to eq("Ventas")
    end
  end

  describe "#duplicate" do
    it "copies the structure (stages) but not the deals, and is not the default" do
      source = Pipeline.create_default!(workspace)
      create_deal!(workspace, pipeline: source)

      copy = source.duplicate
      expect(copy.save).to be(true)

      expect(copy.name).to eq("Ventas#{I18n.t("pipelines.duplicate_name_suffix")}")
      expect(copy).not_to be_default_pipeline
      expect(copy.pipeline_stages.ordered.map { |s| [s.name, s.probability, s.color, s.won, s.closed] })
        .to eq(source.pipeline_stages.ordered.map { |s| [s.name, s.probability, s.color, s.won, s.closed] })
      expect(copy.deals).to be_empty
    end

    it "accepts a custom name" do
      source = Pipeline.create_default!(workspace)
      expect(source.duplicate(name: "Partners").name).to eq("Partners")
    end

    it "copies card_fields" do
      source = Pipeline.create_default!(workspace)
      source.update!(card_fields: %w[value products contacts])

      copy = source.duplicate
      expect(copy.save).to be(true)
      expect(copy.card_fields).to eq(%w[value products contacts])
    end
  end

  describe ".card_field_label" do
    it "follows the current locale" do
      expect(described_class.card_field_label("value")).to eq("Importe")
      expect(described_class.card_field_label("products")).to eq("Productos y ediciones")

      I18n.with_locale(:en) do
        expect(described_class.card_field_label("value")).to eq("Value")
        expect(described_class.card_field_label("products")).to eq("Products and editions")
      end
    end
  end

  describe "card_fields" do
    it "normalizes unknown keys on save" do
      pipeline = Pipeline.create_default!(workspace)
      pipeline.card_fields = %w[value unknown products]
      pipeline.save!

      expect(pipeline.card_fields).to eq(%w[value products])
    end
  end

  describe "validations" do
    it "requires at least one stage" do
      pipeline = workspace.pipelines.new(name: "Empty")
      expect(pipeline).not_to be_valid
      expect(pipeline.errors[:base]).to include(I18n.t("pipelines.validation.needs_stage"))
    end
  end

  describe "#reorder_stages!" do
    it "updates positions to match the given id list" do
      pipeline = Pipeline.create_default!(workspace)
      stages = pipeline.pipeline_stages.ordered.to_a
      new_order = [stages[3].id, stages[0].id, stages[1].id, stages[2].id, stages[4].id, stages[5].id]

      expect(pipeline.reorder_stages!(new_order)).to be(true)
      expect(pipeline.pipeline_stages.ordered.pluck(:id)).to eq(new_order)
    end

    it "returns false when the id list is incomplete" do
      pipeline = Pipeline.create_default!(workspace)

      expect(pipeline.reorder_stages!([pipeline.first_stage.id])).to be(false)
    end
  end
end
