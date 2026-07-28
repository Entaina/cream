require "rails_helper"

RSpec.describe SalesDirectorBriefingJob, type: :job do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:team_director) { instance_double(Ai::SalesDirector, call: true) }
  let(:personal_director) { instance_double(Ai::PersonalSalesDirector, call: true) }

  before do
    workspace.update!(sales_director_enabled: true)
    allow(Ai::SalesDirector).to receive(:new).with(workspace: workspace).and_return(team_director)
    allow(Ai::PersonalSalesDirector).to receive(:new).and_return(personal_director)
  end

  it "generates team and personal briefings for each workspace member" do
    described_class.perform_now(workspace.id)

    expect(Ai::SalesDirector).to have_received(:new).with(workspace: workspace)
    expect(team_director).to have_received(:call)
    workspace.users.each do |user|
      expect(Ai::PersonalSalesDirector).to have_received(:new).with(workspace: workspace, user: user)
    end
    expect(personal_director).to have_received(:call).exactly(workspace.users.count).times
  end

  it "skips personal briefings for members who disabled the preference" do
    memberships(:one_member).update!(sales_director_briefing_enabled: false)

    described_class.perform_now(workspace.id)

    expect(Ai::SalesDirector).to have_received(:new).with(workspace: workspace)
    expect(team_director).to have_received(:call)
    expect(Ai::PersonalSalesDirector).to have_received(:new).with(workspace: workspace, user: users(:one))
    expect(Ai::PersonalSalesDirector).to have_received(:new).with(workspace: workspace, user: users(:three))
    expect(Ai::PersonalSalesDirector).not_to have_received(:new).with(workspace: workspace, user: users(:two))
    enabled_count = workspace.memberships.where(sales_director_briefing_enabled: true).count
    expect(personal_director).to have_received(:call).exactly(enabled_count).times
  end

  it "only processes workspaces with sales director enabled when no workspace id is given" do
    enabled_workspace = workspace
    disabled_workspace = workspaces(:two)
    disabled_team_director = instance_double(Ai::SalesDirector, call: true)
    disabled_personal_director = instance_double(Ai::PersonalSalesDirector, call: true)

    allow(Ai::SalesDirector).to receive(:new).with(workspace: disabled_workspace).and_return(disabled_team_director)
    allow(Ai::PersonalSalesDirector).to receive(:new).with(hash_including(workspace: disabled_workspace)).and_return(disabled_personal_director)

    described_class.perform_now

    expect(Ai::SalesDirector).to have_received(:new).with(workspace: enabled_workspace)
    expect(Ai::SalesDirector).not_to have_received(:new).with(workspace: disabled_workspace)
  end
end
