# Cream never uploads directly from the browser; the endpoint is public by default.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.before_action { head :not_found }
end
