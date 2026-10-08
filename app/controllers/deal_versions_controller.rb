class DealVersionsController < ApplicationController
  # Domain events shown alongside PaperTrail versions; attribute create/update
  # is covered by versions alone to avoid duplicate rows.
  ACTIVITY_ACTIONS = %w[
    note_added comment_added attachment_added email_opened email_clicked
    task_completed stage_changed pipeline_changed contacts_changed products_changed offer_viewed
  ].freeze

  before_action :set_deal

  def index
    authorize @deal, :show?
    @versions = scoped_versions.order(created_at: :desc, id: :desc)
    @activities = @deal.activities.includes(:user)
      .where(workspace: current_workspace, action: ACTIVITY_ACTIONS)
      .recent_first
    @audit_timeline = build_audit_timeline(@versions, @activities)
  end

  def show
    authorize @deal, :show?
    @version = scoped_versions.find(params[:id])
    @snapshot = @deal.paper_trail.version_at(@version.created_at) || @version.reify || @deal
  end

  private

  def set_deal
    @deal = policy_scope(current_workspace.deals).find(params[:deal_id])
  end

  def scoped_versions
    @deal.versions.where(workspace_id: [current_workspace.id, nil])
  end

  def build_audit_timeline(versions, activities)
    entries = versions.map { |v| {kind: :version, record: v, at: v.created_at, tie: v.id} }
    entries += activities.map { |a| {kind: :activity, record: a, at: a.created_at, tie: a.id} }
    entries.sort_by { |e| [-e[:at].to_i, -e[:tie]] }
  end
end
