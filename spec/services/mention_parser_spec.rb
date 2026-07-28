require "rails_helper"

RSpec.describe MentionParser do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:member) { users(:two) }

  describe ".users_from" do
    it "finds users by email prefix handle" do
      users = described_class.users_from("Please review @two", workspace: workspace)

      expect(users).to eq([ member ])
    end
  end

  describe ".render_html" do
    it "highlights mentions matched by email prefix handle" do
      html = described_class.render_html("Hey @two please review", workspace: workspace)

      expect(html).to include('<span class="text-accent font-medium">@User Two</span>')
    end
  end
end
