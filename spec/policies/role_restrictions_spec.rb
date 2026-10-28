require "rails_helper"

RSpec.describe "Role restrictions" do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:director) { users(:three) }
  let(:other_salesperson) { users(:outsider) }

  before { workspace.memberships.create!(user: other_salesperson, role: "salesperson") }

  def allowed?(user, record, action)
    Pundit.policy!(UserContext.new(user: user, workspace: workspace), record).public_send(action)
  end

  describe "workspace configuration" do
    [Pipeline, Product, LeadForm, StageTrigger, StageCondition, StageFieldFormat].each do |model|
      context model.name do
        let(:record) { model.new(workspace: workspace) }

        it "lets admins and sales directors change it" do
          [admin, director].each do |user|
            %i[create? update? destroy?].each { |action| expect(allowed?(user, record, action)).to be(true), "#{user.email_address} #{action}" }
          end
        end

        it "lets salespeople read it but not change it" do
          expect(allowed?(salesperson, record, :index?)).to be true
          expect(allowed?(salesperson, record, :show?)).to be true
          %i[create? update? destroy?].each { |action| expect(allowed?(salesperson, record, action)).to be(false), action.to_s }
        end
      end
    end

    it "blocks reordering pipeline stages for salespeople" do
      expect(allowed?(salesperson, Pipeline.new(workspace: workspace), :reorder_stages?)).to be false
      expect(allowed?(director, Pipeline.new(workspace: workspace), :reorder_stages?)).to be true
    end

    it "still lets salespeople add editions while attaching products to a deal" do
      edition = Edition.new

      expect(allowed?(salesperson, edition, :create?)).to be true
      expect(allowed?(salesperson, Edition.new(workspace: workspace), :update?)).to be false
      expect(allowed?(salesperson, Edition.new(workspace: workspace), :destroy?)).to be false
      expect(allowed?(director, Edition.new(workspace: workspace), :update?)).to be true
    end

    it "does not let salespeople add editions to another workspace" do
      expect(allowed?(salesperson, Edition.new(workspace: workspaces(:two)), :create?)).to be false
    end
  end

  describe "notes, comments and attachments" do
    [Note, Comment, RecordAttachment].each do |model|
      context model.name do
        let(:record) { model.new(workspace: workspace, user: salesperson) }

        it "lets the author and admins change it" do
          [salesperson, admin].each do |user|
            expect(allowed?(user, record, :update?)).to be true
            expect(allowed?(user, record, :destroy?)).to be true
          end
        end

        it "does not let other members change it" do
          [other_salesperson, director].each do |user|
            expect(allowed?(user, record, :update?)).to be false
            expect(allowed?(user, record, :destroy?)).to be false
          end
        end
      end
    end
  end

  describe "companies" do
    let(:company) { workspace.companies.new }

    it "only lets admins delete them" do
      expect(allowed?(admin, company, :destroy?)).to be true
      expect(allowed?(director, company, :destroy?)).to be false
      expect(allowed?(salesperson, company, :destroy?)).to be false
    end

    it "still lets salespeople edit them" do
      expect(allowed?(salesperson, company, :update?)).to be true
    end
  end

  describe "reports" do
    let(:report) { workspace.reports.new(user: salesperson, shared: true) }

    it "lets the owner and admins change shared reports" do
      [salesperson, admin].each do |user|
        expect(allowed?(user, report, :update?)).to be true
        expect(allowed?(user, report, :destroy?)).to be true
      end
    end

    it "does not let other members change shared reports" do
      [other_salesperson, director].each do |user|
        expect(allowed?(user, report, :update?)).to be false
        expect(allowed?(user, report, :destroy?)).to be false
      end
    end
  end

  describe "email templates" do
    let(:private_template) { workspace.email_templates.new(user: salesperson, shared: false) }

    it "keeps private templates to their author and admins" do
      expect(allowed?(salesperson, private_template, :show?)).to be true
      expect(allowed?(admin, private_template, :show?)).to be true
      expect(allowed?(other_salesperson, private_template, :show?)).to be false
    end

    it "shows shared templates to every member" do
      shared = workspace.email_templates.new(user: salesperson, shared: true)

      expect(allowed?(other_salesperson, shared, :show?)).to be true
    end
  end
end
