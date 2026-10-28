class ApiTokensController < ApplicationController
  def index
    @api_tokens = policy_scope(current_user.api_tokens).order(created_at: :desc)
  end

  def create
    token = current_user.api_tokens.build(
      name: params[:name].presence || "API token",
      workspace: current_workspace,
      token_scope: params[:token_scope].presence || "write",
      expires_at: requested_expiry
    )
    authorize token

    if token.save
      flash[:api_token] = token.plaintext_token
      redirect_to api_tokens_path, notice: t("flashes.api_tokens.created")
    else
      redirect_to api_tokens_path, alert: token.errors.full_messages.to_sentence
    end
  end

  def destroy
    token = policy_scope(current_user.api_tokens).find(params[:id])
    authorize token
    token.destroy!
    redirect_to api_tokens_path, notice: t("flashes.api_tokens.revoked")
  end

  private

  def requested_expiry
    days = params[:expires_in_days].to_i
    days.days.from_now if ApiToken::EXPIRY_DAYS.include?(days)
  end
end
