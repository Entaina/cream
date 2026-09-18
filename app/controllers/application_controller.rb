class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include Pagy::Method
  include SetLocale
  include SetTimeZone

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_workspace
  before_action :ensure_workspace_membership
  before_action :set_current_pipeline
  before_action :set_paper_trail_whodunnit

  after_action :verify_authorized, if: -> { pundit_verifiable_controller? && action_name != "index" }
  after_action :verify_policy_scoped, if: -> { pundit_verifiable_controller? && action_name == "index" }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from Pagy::RangeError, with: :pagy_redirect_to_last_page

  helper_method :current_workspace, :current_user, :current_pipeline, :current_membership, :show_closed?

  private

  # Doorkeeper's own controllers inherit from ApplicationController (see the
  # Doorkeeper initializer's `base_controller`) but never call `authorize` /
  # `policy_scope`, so Pundit's verification callbacks would raise on them. They
  # handle their own authentication via `resource_owner_authenticator`.
  def pundit_verifiable_controller?
    !self.class.name.to_s.start_with?("Doorkeeper::")
  end

  def current_user = Current.user

  def current_workspace = Current.workspace

  def current_pipeline = Current.pipeline

  def show_closed?
    params[:closed] == "1"
  end

  def current_membership
    return @current_membership if defined?(@current_membership)

    @current_membership = current_user&.memberships&.find_by(workspace: current_workspace)
  end

  def pundit_user
    UserContext.new(user: current_user, workspace: current_workspace)
  end

  def set_current_workspace
    Current.workspace = Current.user&.active_workspace(session_workspace_id: session[:workspace_id])
  end

  def ensure_workspace_membership
    return unless current_user

    raise Pundit::NotAuthorizedError unless current_workspace && pundit_user.member?
  end

  def set_current_pipeline
    return unless current_workspace && current_membership

    Current.pipeline = current_workspace.pipelines.find_by(id: current_membership.current_pipeline_id)
  end

  def set_paper_trail_whodunnit
    PaperTrail.request.whodunnit = Current.user&.id&.to_s
  end

  def info_for_paper_trail
    {workspace_id: Current.workspace&.id}
  end

  def pagy_redirect_to_last_page(exception)
    redirect_to url_for(request.query_parameters.merge(page: exception.pagy.last))
  end

  def user_not_authorized
    respond_to do |format|
      format.html do
        destination = (request.path == root_path) ? new_session_path : root_path
        redirect_to destination, alert: t("auth.flashes.not_authorized")
      end
      format.json { head :forbidden }
      format.any { head :forbidden }
    end
  end
end
