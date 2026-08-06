namespace :lead_form_templates do
  desc "Import public lead form views from the repository into a workspace (idempotent)"
  task :import, [ :workspace_id ] => :environment do |_task, args|
    workspace_id = args[:workspace_id].presence
    abort "Usage: rake lead_form_templates:import[WORKSPACE_ID]" if workspace_id.blank?

    workspace = Workspace.find_by(id: workspace_id)
    abort "Workspace #{workspace_id} not found" unless workspace

    result = LeadFormTemplates::Importer.import!(workspace)

    puts "Imported lead form templates for workspace #{workspace.id} (#{workspace.name})"
    puts "  created: #{result[:created]}"
    puts "  updated: #{result[:updated]}"
    puts "  total:   #{result[:total]}"
  end
end
