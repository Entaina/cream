class RecordAiController < ApplicationController
  include RequiresFeature

  requires_feature :ai_assistant

  before_action :set_record

  def summary
    authorize @record, :show?
    render json: Ai::RecordSummarizer.new(record: @record, user: current_user).call
  rescue Ai::Client::NotConfigured
    render json: { error: "AI is not configured. Set CREAM_AI_API_KEY." }, status: :service_unavailable
  rescue Ai::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def draft_email
    authorize @record, :show?
    render json: Ai::EmailDrafter.new(
      record: @record,
      user: current_user,
      goal: params[:goal]
    ).call
  rescue Ai::Client::NotConfigured
    render json: { error: "AI is not configured. Set CREAM_AI_API_KEY." }, status: :service_unavailable
  rescue Ai::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def next_steps
    authorize @record, :show?
    render json: Ai::NextStepSuggester.new(record: @record, user: current_user).call
  rescue Ai::Client::NotConfigured
    render json: { error: "AI is not configured. Set CREAM_AI_API_KEY." }, status: :service_unavailable
  rescue Ai::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create_task
    authorize @record, :show?

    task = current_workspace.tasks.new(
      title: params[:title],
      due_on: params[:due_on],
      taskable: @record,
      user: current_user,
      assignee: current_user
    )
    authorize task, :create?

    if task.save
      @record.track_activity(
        "ai_task_created",
        metadata: { title: task.title, reason: params[:reason].presence }.compact
      )
      render json: { task: { id: task.id, title: task.title, due_on: task.due_on&.iso8601 } }
    else
      render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def enrich
    requires_ai_enrichment!
    authorize @record, :show?
    render json: Ai::RecordEnricher.new(record: @record, user: current_user).call
  rescue Ai::Client::NotConfigured
    render json: { error: "AI is not configured. Set CREAM_AI_API_KEY." }, status: :service_unavailable
  rescue Ai::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_record
    @record = Ai::RecordResolver.find!(current_workspace, params[:record_type], params[:record_id])
  end

  def requires_ai_enrichment!
    return if CreamFeatures.enabled?(:ai_enrichment)

    render json: { error: "AI enrichment is not available yet." }, status: :not_found
  end
end
