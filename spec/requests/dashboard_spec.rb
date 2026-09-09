require "rails_helper"

RSpec.describe "Dashboard active pipeline", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:membership) { memberships(:one_one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }

  before { sign_in_as(member) }

  it "filters open pipeline metrics by the active pipeline" do
    other = pipeline.duplicate(name: "Partners").tap(&:save!)
    create_deal!(workspace, pipeline: pipeline, value: 1000)
    create_deal!(workspace, pipeline: other, value: 5000)
    membership.update!(current_pipeline: pipeline)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("1.000 €")
    expect(response.body).not_to include("5.000 €")
  end

  it "shows all deal metrics when all pipelines is selected" do
    other = pipeline.duplicate(name: "Partners").tap(&:save!)
    create_deal!(workspace, pipeline: pipeline, value: 1000)
    create_deal!(workspace, pipeline: other, value: 5000)
    membership.update!(current_pipeline: nil)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("6.000 €")
  end

  describe "sales director section" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:sales_director).and_return(true)
      workspace.update!(sales_director_enabled: true)
    end

    it "shows an empty state when AI is configured but no briefing exists" do
      allow(Ai::Configuration).to receive(:configured?).and_return(true)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Director de ventas")
      expect(response.body).to include("Generar ahora")
    end

    it "shows urgent and important items when a briefing exists" do
      allow(Ai::Configuration).to receive(:configured?).and_return(true)
      workspace.sales_briefings.create!(
        briefing_date: Date.current,
        summary: "Pipeline estable con riesgos puntuales",
        items: [
          { "priority" => "urgent", "text" => "Llamar a ACME hoy", "owner_id" => member.id },
          { "priority" => "important", "text" => "Preparar propuesta para Beta" }
        ],
        wins: [],
        misses: [],
        generated_at: Time.current
      )

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Equipo")
      expect(response.body).to include("Pipeline estable con riesgos puntuales")
      expect(response.body).to include("Urgente")
      expect(response.body).to include("Llamar a ACME hoy")
      expect(response.body).to include("Preparar propuesta para Beta")
      expect(response.body).to include("Regenerar")
      expect(response.body).to include("Quedan 5 regeneraciones hoy")
      expect(response.body).not_to include("Generar ahora")
    end

    it "hides the regenerate button when the daily limit is reached" do
      allow(Ai::Configuration).to receive(:configured?).and_return(true)
      membership.update!(
        sales_briefing_regenerations_count: 5,
        sales_briefing_regenerations_on: Date.current
      )
      workspace.sales_briefings.create!(
        briefing_date: Date.current,
        summary: "Pipeline estable con riesgos puntuales",
        items: [
          { "priority" => "urgent", "text" => "Llamar a ACME hoy", "owner_id" => member.id },
          { "priority" => "important", "text" => "Preparar propuesta para Beta" }
        ],
        wins: [],
        misses: [],
        generated_at: Time.current
      )

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Regenerar")
      expect(response.body).not_to include("Generar ahora")
      expect(response.body).to include("Has usado las 5 regeneraciones de hoy")
    end

    it "shows the personal briefing for the current user only" do
      allow(Ai::Configuration).to receive(:configured?).and_return(true)
      workspace.sales_briefings.create!(
        user: member,
        briefing_date: Date.current,
        summary: "Hoy debes cerrar ACME",
        items: [ { "priority" => "urgent", "text" => "Llama a ACME antes del mediodía" } ],
        wins: [ "Ganaste el deal Beta la semana pasada" ],
        misses: [ "Dejaste vencer la tarea con Gamma" ],
        generated_at: Time.current
      )
      workspace.sales_briefings.create!(
        user: users(:two),
        briefing_date: Date.current,
        summary: "Briefing de otro usuario",
        items: [ { "priority" => "urgent", "text" => "No deberías ver esto" } ],
        wins: [ "Secreto" ],
        misses: [ "Privado" ],
        generated_at: Time.current
      )

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Para ti")
      expect(response.body).to include("Hoy debes cerrar ACME")
      expect(response.body).to include("Ganaste el deal Beta la semana pasada")
      expect(response.body).to include("Dejaste vencer la tarea con Gamma")
      expect(response.body).not_to include("Briefing de otro usuario")
      expect(response.body).not_to include("No deberías ver esto")
      expect(response.body).not_to include("Secreto")
    end

    it "hides the section when AI is not configured" do
      allow(Ai::Configuration).to receive(:configured?).and_return(false)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Director de ventas")
    end

    it "hides the section when sales director is disabled for the workspace" do
      allow(Ai::Configuration).to receive(:configured?).and_return(true)
      workspace.update!(sales_director_enabled: false)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Director de ventas")
    end

    it "hides the section when the user disabled the briefing in profile" do
      allow(Ai::Configuration).to receive(:configured?).and_return(true)
      memberships(:one_one).update!(sales_director_briefing_enabled: false)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Director de ventas")
    end
  end

  describe "salesperson deal metrics" do
    it "shows only owned and shared deals for a salesperson" do
      salesperson = users(:two)
      admin = users(:one)
      create_deal!(workspace, pipeline: pipeline, owner: salesperson, value: 1000, name: "Own dashboard deal")
      shared_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, value: 2000, name: "Shared dashboard deal")
      shared_deal.deal_accesses.create!(user: salesperson)
      create_deal!(workspace, pipeline: pipeline, owner: admin, value: 9000, name: "Hidden dashboard deal")
      memberships(:one_member).update!(current_pipeline: pipeline)

      sign_in_as(salesperson)
      patch switch_workspace_path, params: { workspace_id: workspace.id }
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("3.000 €")
      expect(response.body).not_to include("9.000 €")
    end
  end

  describe "My tasks" do
    it "shows only pending tasks assigned to the current user" do
      workspace.tasks.create!(
        title: "My pending task",
        user: member,
        assignee: member,
        due_on: Date.current
      )
      workspace.tasks.create!(
        title: "Teammate pending task",
        user: users(:two),
        assignee: users(:two),
        due_on: Date.current
      )

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My pending task")
      expect(response.body).not_to include("Teammate pending task")
    end
  end

  describe "all pipelines in the stage chart" do
    it "groups stages by name with stacked pipeline segments when all pipelines is selected" do
      other = pipeline.duplicate(name: "Partners").tap(&:save!)
      lead_default = pipeline.pipeline_stages.find_by!(name: "Lead")
      lead_other = other.pipeline_stages.find_by!(name: "Lead")
      create_deal!(workspace, pipeline: pipeline, stage: lead_default, name: "Ventas dashboard deal")
      create_deal!(workspace, pipeline: other, stage: lead_other, name: "Partners dashboard deal")
      membership.update!(current_pipeline: nil)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('title="Ventas: 1"')
      expect(response.body).to include('title="Partners: 1"')
      expect(response.body.scan(/>Lead</).size).to eq(1)
    end
  end

  describe "closed stages in the stage chart" do
    it "hides closed stages by default" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(">Won</span>")
      expect(response.body).not_to include(">Lost</span>")
    end

    it "shows closed stages when closed=1" do
      membership.update!(current_pipeline: pipeline)

      get root_path, params: { closed: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(">Won</span>")
      expect(response.body).to include(">Lost</span>")
    end

    it "links each stage bar to the filtered deals list" do
      stage = pipeline.pipeline_stages.first
      create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Dashboard linked deal")
      membership.update!(current_pipeline: pipeline)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("stage=#{stage.id}")
      expect(response.body).to include("pipeline_id=#{pipeline.id}")
      expect(response.body).to include('href="/deals')
    end
  end
end
