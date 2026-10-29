class OkmChatsController < ApplicationController
  include RequiresFeature
  include ActionController::Live

  requires_feature :okm_chat

  before_action :ensure_okm_chat_workspace!

  def create
    response.headers["Content-Type"] = "application/x-ndjson; charset=utf-8"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    @record = resolve_record if record_context_requested?

    if @record
      authorize @record, :show?
    else
      authorize current_workspace, :show?
    end

    result = Ai::ContextualAgent.new(
      workspace: current_workspace,
      user: current_user,
      record: @record,
      message: chat_params[:message],
      history: chat_params[:history],
      session_id: chat_params[:session_id],
      on_status: ->(message) { stream_event(type: "status", message: message) }
    ).call

    stream_event(type: "reply", content: result.reply.presence || t("shared.okm_chat.no_reply"))
    stream_event(type: "session", session_id: result.session_id) if result.session_id.present?

    result.pending_actions.each do |action|
      stream_event(
        type: "confirm_action",
        description: action.description,
        preview: action.preview,
        token: action.sign
      )
    end
  rescue ActiveRecord::RecordNotFound
    stream_event(type: "error", message: "Record not found.", status: :not_found)
  rescue ArgumentError => e
    stream_event(type: "error", message: e.message, status: :unprocessable_entity)
  rescue Ai::Client::NotConfigured
    stream_event(type: "error", message: "AI is not configured. Set CREAM_AI_API_KEY.", status: :service_unavailable)
  rescue Ai::Client::Error => e
    stream_event(type: "error", message: e.message, status: :unprocessable_entity)
  ensure
    begin
      response.stream.close
    rescue IOError
      nil
    end
  end

  def execute_action
    action = Ai::Agent::PendingAction.from_verified(action_params[:token])

    unless action.workspace_id == current_workspace.id && action.user_id == current_user.id
      return render json: {error: "Invalid action token."}, status: :forbidden
    end

    authorize current_workspace, :show?

    return render json: {error: "Action already executed."}, status: :conflict unless action.consume!

    result = Ai::Agent::ActionExecutor.new(workspace: current_workspace, user: current_user).execute(action)

    if result.success
      render json: {success: true, message: result.message, data: result.data}
    else
      render json: {success: false, message: result.message}, status: :unprocessable_entity
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render json: {error: "Invalid or expired action token."}, status: :unprocessable_entity
  end

  private

  def ensure_okm_chat_workspace!
    return if current_workspace&.okm_chat_enabled? && current_workspace.okm_configured?

    render json: {error: CreamFeatures.unavailable_in_workspace_message(:okm_chat)}, status: :not_found
  end

  def resolve_record
    Ai::RecordResolver.find!(current_workspace, record_type_param, record_id_param)
  end

  def record_context_requested?
    record_type_param.present? && record_id_param.present?
  end

  def chat_params
    params.permit(:message, :session_id, history: [:role, :content])
  end

  def action_params
    params.permit(:token)
  end

  def record_type_param
    params[:record_type].presence
  end

  def record_id_param
    params[:record_id].presence
  end

  def stream_event(payload)
    response.status = payload.delete(:status) || :ok
    response.stream.write("#{payload.to_json}\n")
  end
end
