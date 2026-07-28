# Deals created before PaperTrail was enabled have no versions until edited.
# Seed a baseline "create" snapshot so Version history is never empty for existing deals.
class BackfillDealVersions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    serializer = PaperTrail.config.serializer

    Deal.find_each do |deal|
      next if deal.versions.exists?

      deal.versions.create!(
        event: "create",
        object: serializer.dump(deal.attributes),
        workspace_id: deal.workspace_id,
        created_at: deal.created_at,
        whodunnit: deal.owner_id&.to_s
      )
    end
  end

  def down
    # Remove only synthetic baseline rows (create events with no object_changes).
    PaperTrail::Version.where(item_type: "Deal", event: "create", object_changes: nil).delete_all
  end
end
