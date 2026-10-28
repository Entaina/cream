# Rate limit identity for bearer-authenticated endpoints. Counting per token keeps
# clients that share an IP (the Gmail add-on calls from Google's IPs) apart; the
# token is hashed so it never lands in the cache store.
module BearerRateLimit
  private

  def rate_limit_identity
    token = bearer_token
    token ? "token:#{Digest::SHA256.hexdigest(token)}" : "ip:#{request.remote_ip}"
  end
end
