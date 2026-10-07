require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#money" do
    it "omits cents for whole euros" do
      expect(helper.money(1_200)).to eq("1.200 €")
    end

    it "shows cents when the amount is not a whole number" do
      expect(helper.money(590.50)).to eq("590,50 €")
    end

    it "uses English grouping when the locale is English" do
      I18n.with_locale(:en) do
        expect(helper.money(1_200)).to eq("€1,200")
        expect(helper.money(590.50)).to eq("€590.50")
      end
    end
  end

  describe "#activity_actor" do
    fixtures :users, :workspaces, :memberships

    let(:workspace) { workspaces(:one) }
    let(:person) { create_person!(workspace) }

    def build_activity(user: nil, metadata: {})
      Activity.new(workspace: workspace, subject: person, user: user, action: "updated", metadata: metadata)
    end

    it "returns the user name when there is a user" do
      user = workspace.users.first

      expect(helper.activity_actor(build_activity(user: user))).to eq(user.name)
    end

    it "labels scoring automations" do
      activity = build_activity(metadata: {"automation" => {"kind" => "scoring"}})

      expect(helper.activity_actor(activity)).to eq("Automatización (scoring)")
    end

    it "labels form automations with the form name" do
      activity = build_activity(metadata: {"automation" => {"kind" => "form", "name" => "Contacto"}})

      expect(helper.activity_actor(activity)).to eq("Formulario: Contacto")
    end

    it "labels journey automations with the journey name" do
      activity = build_activity(metadata: {"automation" => {"kind" => "journey", "name" => "Bienvenida"}})

      expect(helper.activity_actor(activity)).to eq("Recorrido: Bienvenida")
    end

    it "falls back to someone when the actor is unknown" do
      expect(helper.activity_actor(build_activity)).to eq("Alguien")
    end
  end
end
