RSpec.configure do |config|
  config.before(:each, type: :request) do |example|
    next unless example.metadata[:file_path].include?("spec/requests/public/lead_forms")

    workspace = workspaces(:one)
    SubscriptionType.ensure_defaults!(workspace)
    import_lead_form_templates!(workspace)
  end
end
