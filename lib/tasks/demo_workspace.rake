namespace :cream do
  namespace :demo_workspace do
    desc "Add all existing users to the Cream Demo workspace"
    task backfill_memberships: :environment do
      demo = Workspace.find_by(slug: User::DEMO_WORKSPACE_SLUG)
      abort "Cream Demo workspace not found (slug: #{User::DEMO_WORKSPACE_SLUG}). Run db:seed first." unless demo

      before_count = demo.memberships.count
      User.find_each { |user| User.join_demo_workspace!(user) }
      added = demo.memberships.count - before_count

      puts "Cream Demo: #{added} users added, #{before_count} already members."
    end
  end
end
