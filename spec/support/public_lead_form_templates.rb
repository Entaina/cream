RSpec.configure do |config|
  config.before(:each, type: :request) do |example|
    next unless example.metadata[:file_path].include?("spec/requests/public/lead_forms")

    import_lead_form_templates!(workspaces(:one))
  end
end
