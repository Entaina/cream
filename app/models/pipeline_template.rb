class PipelineTemplate
  TEMPLATES = {
    "sales" => {
      name: "Sales pipeline",
      stages: Pipeline::DEFAULT_STAGES
    },
    "hiring" => {
      name: "Hiring pipeline",
      stages: [
        {name: "Applied", color: "chicago", probability: 10},
        {name: "Screening", color: "hoki", probability: 25},
        {name: "Interview", color: "copperfield", probability: 50},
        {name: "Offer", color: "golden", probability: 75},
        {name: "Hired", color: "green", probability: 100, won: true, closed: true},
        {name: "Rejected", color: "red", probability: 0, closed: true}
      ]
    },
    "fundraising" => {
      name: "Fundraising pipeline",
      stages: [
        {name: "Prospect", color: "chicago", probability: 5},
        {name: "Intro", color: "hoki", probability: 15},
        {name: "Due diligence", color: "copperfield", probability: 40},
        {name: "Term sheet", color: "golden", probability: 70},
        {name: "Closed", color: "green", probability: 100, won: true, closed: true},
        {name: "Passed", color: "red", probability: 0, closed: true}
      ]
    }
  }.freeze

  def self.all
    TEMPLATES.map { |key, data| {key: key, name: data[:name], stages_count: data[:stages].size} }
  end

  def self.create_pipeline!(workspace:, template_key:)
    data = TEMPLATES.fetch(template_key)
    workspace.pipelines.create!(
      name: data[:name],
      position: workspace.pipelines.count,
      default_pipeline: workspace.pipelines.none?,
      pipeline_stages: data[:stages].each_with_index.map { |attrs, i|
        PipelineStage.new(attrs.reverse_merge(won: false, closed: false).merge(position: i, workspace: workspace))
      }
    )
  end
end
