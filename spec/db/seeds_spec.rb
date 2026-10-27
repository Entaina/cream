require "rails_helper"

RSpec.describe "db/seeds.rb" do
  let(:seeds) { Rails.root.join("db/seeds.rb") }

  it "does nothing in production unless CREAM_ALLOW_SEED is true" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
    demo = Workspace.create!(name: "Cream Demo", slug: "cream-demo")
    workspaces_before = Workspace.count
    users_before = User.count

    expect { load seeds }.to output(/Skipping db:seed in production/).to_stderr

    expect(Workspace.count).to eq(workspaces_before)
    expect(User.count).to eq(users_before)
    expect(Workspace.exists?(demo.id)).to be true
  end
end
