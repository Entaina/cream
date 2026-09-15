require "rails_helper"

RSpec.describe "Email layouts", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before { sign_in_as(member) }

  describe "CRUD" do
    it "creates a layout" do
      expect {
        post email_layouts_path, params: {
          email_layout: {
            name: "Branded",
            body: "<html><body>{{ content }}</body></html>"
          }
        }
      }.to change(EmailLayout, :count).by(1)

      expect(response).to redirect_to(email_templates_path)
    end

    it "rejects layout without content placeholder" do
      post email_layouts_path, params: {
        email_layout: {name: "Bad", body: "<html><body></body></html>"}
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates and deletes a layout" do
      layout = workspace.email_layouts.create!(name: "Shell", body: "<div>{{ content }}</div>")

      patch email_layout_path(layout), params: {
        email_layout: {name: "Shell updated", body: "<div>{content}</div>"}
      }
      expect(response).to redirect_to(email_templates_path)
      expect(layout.reload.name).to eq("Shell updated")

      expect {
        delete email_layout_path(layout)
      }.to change(EmailLayout, :count).by(-1)
    end
  end
end
