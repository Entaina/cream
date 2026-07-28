class ApiTokensController < ApplicationController
  def index
    @api_tokens = policy_scope(current_user.api_tokens).order(created_at: :desc)
  end

  def create
    token = current_user.api_tokens.build(
      name: params[:name].presence || "API token",
      workspace: current_workspace
    )
    authorize token

    if token.save
      flash[:api_token] = token.plaintext_token
      redirect_to api_tokens_path, notice: "Token created. Copy it now — it won't be shown again."
    else
      redirect_to api_tokens_path, alert: token.errors.full_messages.to_sentence
    end
  end

  def destroy
    token = policy_scope(current_user.api_tokens).find(params[:id])
    authorize token
    token.destroy!
    redirect_to api_tokens_path, notice: "Token revoked."
  end
end
