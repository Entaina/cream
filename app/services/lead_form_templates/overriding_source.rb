module LeadFormTemplates
  class OverridingSource < Source
    def initialize(workspace:, overrides:)
      super(workspace: workspace)
      @overrides = overrides.stringify_keys
    end

    def find_body(path)
      @overrides[path.to_s] || super
    end
  end
end
