module LeadFormTemplates
  class Source
    REPOSITORY_ROOT = Rails.root.join("lib/lead_form_templates")

    def self.find_body(workspace:, path:)
      new(workspace: workspace).find_body(path)
    end

    def self.read_repository_body(path)
      new(workspace: nil).read_repository_body(path)
    end

    def initialize(workspace:)
      @workspace = workspace
    end

    def find_body(path)
      @workspace.lead_form_templates.find_by(path: path)&.body
    end

    def read_repository_body(path)
      repository_path = REPOSITORY_ROOT.join("#{path}.liquid")
      return File.read(repository_path) if repository_path.exist?

      nil
    end

    def repository_paths
      Dir.glob(REPOSITORY_ROOT.join("**/*.liquid")).sort.map do |file|
        Pathname.new(file).relative_path_from(REPOSITORY_ROOT).to_s.delete_suffix(".liquid")
      end
    end
  end
end
