class LegalPagesController < ApplicationController
  layout "public_document"

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  allow_unauthenticated_access only: %i[terms privacy support]

  def terms
  end

  def privacy
  end

  def support
  end
end
