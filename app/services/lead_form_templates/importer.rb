module LeadFormTemplates
  class Importer
    def self.import!(workspace)
      new(workspace).import!
    end

    def initialize(workspace)
      @workspace = workspace
    end

    def import!
      raise ArgumentError, "workspace is required" if @workspace.nil?

      created = 0
      updated = 0

      paths = Source.new(workspace: @workspace).repository_paths.sort_by do |path|
        repository_partial?(path) ? 0 : 1
      end

      paths.each do |path|
        body = Source.read_repository_body(path)
        partial = repository_partial?(path)

        record = @workspace.lead_form_templates.find_or_initialize_by(path: path)
        if record.new_record?
          created += 1
        elsif record.body != body || record.partial != partial
          updated += 1
        end
        record.partial = partial
        record.body = body
        record.save!
      end

      {created: created, updated: updated, total: @workspace.lead_form_templates.count}
    end

    private

    def repository_partial?(path)
      path.start_with?(LeadFormTemplate::PARTIALS_PREFIX)
    end
  end
end
