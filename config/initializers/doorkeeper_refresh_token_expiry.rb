# Doorkeeper refresh tokens never expire on their own. Reject refresh grants
# whose token was issued more than MAX_AGE ago; every refresh issues a new
# token, so this bounds inactivity rather than the total session length.
# Tokens issued before ENFORCED_FROM count from that date, so connections that
# already existed when the limit was introduced keep working for MAX_AGE.
module DoorkeeperRefreshTokenMaxAge
  MAX_AGE = 90.days
  ENFORCED_FROM = Time.utc(2026, 10, 28)

  private

  def validate_token
    super && refresh_token.created_at.present? && [refresh_token.created_at, ENFORCED_FROM].max > MAX_AGE.ago
  end
end

Doorkeeper::OAuth::RefreshTokenRequest.prepend(DoorkeeperRefreshTokenMaxAge)
