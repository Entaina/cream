# frozen_string_literal: true

require "rails_helper"

RSpec.describe SidebarMenu do
  describe ".default_keys" do
    it "returns daily, marketing, and profile keys for non-admins" do
      keys = described_class.default_keys(admin: false)

      expect(keys).to include("dashboard", "people", "marketing_campaigns", "profile", "lists")
      expect(keys).not_to include("products", "pipelines", "workspace", "team")
    end

    it "includes settings keys for admins" do
      keys = described_class.default_keys(admin: true)

      expect(keys).to include("products", "pipelines", "workspace", "team", "reports")
    end

    it "does not include mail_merge" do
      expect(described_class.default_keys(admin: true)).not_to include("mail_merge")
    end
  end

  describe ".merge_order" do
    it "preserves custom order within each group without crossing groups" do
      default_keys = described_class.default_keys(admin: true)
      saved = %w[tasks deals marketing_campaigns profile dashboard people companies marketing_segments]

      merged = described_class.merge_order(saved, default_keys)

      daily = merged.select { |key| described_class.group_for(key) == :daily }
      expect(daily.first(2)).to eq(%w[tasks deals])
      expect(daily).to eq(%w[tasks deals dashboard people companies])

      marketing = merged.select { |key| described_class.group_for(key) == :marketing }
      expect(marketing.first(2)).to eq(%w[marketing_campaigns marketing_segments])

      profile = merged.select { |key| described_class.group_for(key) == :profile }
      expect(profile.first).to eq("profile")
    end

    it "drops orphan keys such as mail_merge" do
      default_keys = described_class.default_keys(admin: true)
      saved = %w[mail_merge dashboard tasks]

      merged = described_class.merge_order(saved, default_keys)

      expect(merged).not_to include("mail_merge")
      expect(merged.first(2)).to eq(%w[dashboard tasks])
    end
  end
end
