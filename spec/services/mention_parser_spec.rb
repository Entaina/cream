require "rails_helper"

RSpec.describe MentionParser do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:member) { users(:two) }

  describe ".users_from" do
    it "finds users by email prefix handle" do
      users = described_class.users_from("Please review @two", workspace: workspace)

      expect(users).to eq([member])
    end
  end

  describe ".render_html" do
    it "highlights mentions matched by email prefix handle" do
      html = described_class.render_html("Hey @two please review", workspace: workspace)

      expect(html).to include('<span class="text-accent font-medium">@User Two</span>')
    end

    it "autolinks URLs and highlights mentions in the same comment" do
      html = described_class.render_html("Hey @two check https://example.com please", workspace: workspace)

      expect(html).to include('<span class="text-accent font-medium">@User Two</span>')
      expect(html).to include('href="https://example.com"')
    end

    it "does not treat @handles inside URLs as mentions" do
      html = described_class.render_html("See https://host/@two/path", workspace: workspace)

      expect(html).to include('href="https://host/@two/path"')
      expect(html).not_to include('<span class="text-accent font-medium">')
    end
  end
end
