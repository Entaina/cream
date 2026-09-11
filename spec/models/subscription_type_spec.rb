require "rails_helper"

RSpec.describe SubscriptionType do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  describe ".ensure_defaults!" do
    it "seeds consent field keys for general and newsletter" do
      described_class.ensure_defaults!(workspace)

      general = workspace.subscription_types.find_by!(slug: "general")
      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
      events = workspace.subscription_types.find_by!(slug: "events")

      expect(general.consent_field_key).to eq("marketing_consent")
      expect(general.default_consent_label).to be_present
      expect(newsletter.consent_field_key).to eq("newsletter_opt_in")
      expect(newsletter.default_consent_label).to be_present
      expect(events.consent_field_key).to be_nil
    end

    it "does not overwrite an existing consent field key" do
      described_class.ensure_defaults!(workspace)
      type = workspace.subscription_types.find_by!(slug: "newsletter")
      type.update!(consent_field_key: "custom_newsletter")

      described_class.ensure_defaults!(workspace)

      expect(type.reload.consent_field_key).to eq("custom_newsletter")
    end
  end

  describe "validations" do
    it "rejects reserved consent field keys" do
      type = workspace.subscription_types.build(name: "Test", slug: "test", consent_field_key: "gdpr_consent")

      expect(type).not_to be_valid
      expect(type.errors[:consent_field_key]).to include("is reserved")
    end

    it "requires unique consent field keys per workspace" do
      described_class.ensure_defaults!(workspace)
      duplicate = workspace.subscription_types.build(
        name: "Dup",
        slug: "dup",
        consent_field_key: "newsletter_opt_in"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:consent_field_key]).to include(I18n.t("errors.messages.taken"))
    end
  end
end
