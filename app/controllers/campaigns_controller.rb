class CampaignsController < ApplicationController
  include RequiresFeature

  requires_feature :marketing_campaigns
  before_action :set_campaign, only: %i[show edit update destroy send_campaign send_test cancel_send mark_winner send_winner_rest recipient_count]

  def index
    @campaigns = policy_scope(current_workspace.campaigns).ordered
    authorize Campaign
  end

  def show
    authorize @campaign
    @sends = @campaign.campaign_sends.includes(:segment, :email_template, :campaign_variants, :journey).order(created_at: :desc)
    @stats = campaign_stats
    @person_segments = current_workspace.segments.where(record_type: "Person").ordered
    @journeys = current_workspace.journeys.active.ordered
    SubscriptionType.ensure_defaults!(current_workspace)
    @subscription_types = current_workspace.subscription_types.active.ordered
  end

  def new
    @campaign = current_workspace.campaigns.new(status: "draft")
    authorize @campaign
    load_email_form_collections
  end

  def create
    @campaign = current_workspace.campaigns.new(campaign_params)
    authorize @campaign
    if @campaign.save
      redirect_to @campaign, notice: t("flashes.campaigns.created")
    else
      load_email_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @campaign
    load_email_form_collections
  end

  def update
    authorize @campaign
    if @campaign.update(campaign_params)
      redirect_to @campaign, notice: t("flashes.campaigns.updated")
    else
      load_email_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @campaign
    @campaign.destroy
    redirect_to campaigns_path, notice: t("flashes.campaigns.deleted"), status: :see_other
  end

  def send_campaign
    authorize @campaign, :update?
    delivery_mode = params[:delivery_mode].presence_in(CampaignSend::DELIVERY_MODES) || "email"

    if delivery_mode.in?(%w[email both]) && !@campaign.email_content_present?
      return redirect_to edit_campaign_path(@campaign), alert: t("flashes.campaigns.missing_email_content")
    end

    journey = nil
    if delivery_mode.in?(%w[journey both])
      journey = current_workspace.journeys.active.find_by(id: params[:journey_id])
      return redirect_to(@campaign, alert: t("flashes.campaigns.pick_active_journey")) unless journey
    end

    segment = current_workspace.segments.find(params[:segment_id])
    return redirect_to(@campaign, alert: t("flashes.campaigns.segment_must_be_people")) unless segment.record_type == "Person"

    subscription_type = resolve_subscription_type
    send_record = current_workspace.campaign_sends.create!(
      campaign: @campaign,
      segment: segment,
      email_template: @campaign.email_template,
      journey: journey,
      delivery_mode: delivery_mode,
      user: current_user,
      subscription_type: subscription_type,
      status: "pending",
      scheduled_at: params[:scheduled_at].presence
    )
    create_variants!(send_record)

    if send_record.scheduled_at.present? && send_record.scheduled_at > Time.current
      send_record.mark_scheduled!
      @campaign.update!(status: "scheduled")
      CampaignSendJob.set(wait_until: send_record.scheduled_at).perform_later(send_record.id)
      redirect_to @campaign, notice: t("flashes.campaigns.send_scheduled")
    else
      CampaignSendJob.perform_later(send_record.id)
      redirect_to @campaign, notice: t("flashes.campaigns.send_queued")
    end
  end

  def send_test
    authorize @campaign, :update?
    unless @campaign.email_content_present?
      return redirect_to edit_campaign_path(@campaign), alert: t("flashes.campaigns.missing_email_content_test")
    end

    person = current_workspace.people.with_email(current_user.email_address).first ||
      create_test_person!(current_user.email_address)
    email_content = @campaign.email_content

    variant = build_test_variant(email_content)
    subject, body = if variant
      email_content.render_custom_for(person, subject: variant[:subject], body: variant[:body])
    else
      [email_content.render_subject_for(person), email_content.render_for(person)]
    end

    message = current_workspace.email_messages.create!(
      user: current_user,
      record: person,
      to_address: current_user.email_address,
      subject: "[Prueba] #{subject}",
      body: body,
      campaign: @campaign,
      marketing_send: false
    )
    Marketing::Esp::Client.for(message).deliver!
    redirect_to @campaign, notice: t("flashes.campaigns.test_sent", email: current_user.email_address)
  rescue => e
    redirect_to @campaign, alert: t("flashes.campaigns.test_send_failed", message: e.message)
  end

  def cancel_send
    authorize @campaign, :update?
    send_record = @campaign.campaign_sends.find(params[:send_id])
    send_record.cancel!
    redirect_to @campaign, notice: t("flashes.campaigns.send_cancelled")
  end

  def mark_winner
    authorize @campaign, :update?
    send_record = @campaign.campaign_sends.find(params[:send_id])
    variant = send_record.campaign_variants.find(params[:variant_id])
    send_record.campaign_variants.update_all(winner: false)
    variant.update!(winner: true)
    redirect_to @campaign, notice: t("flashes.campaigns.variant_winner", name: variant.name)
  end

  def send_winner_rest
    authorize @campaign, :update?
    source_send = @campaign.campaign_sends.find(params[:send_id])
    winner = source_send.campaign_variants.find_by!(winner: true)
    segment = source_send.segment
    already_sent = @campaign.email_messages.where(marketing_send: true).select(:to_address)
    remaining = segment.resolve(current_workspace.people).reject { |p| already_sent.where(to_address: p.email).exists? }

    send_record = current_workspace.campaign_sends.create!(
      campaign: @campaign,
      segment: segment,
      email_template: source_send.email_template,
      user: current_user,
      subscription_type: source_send.subscription_type,
      status: "pending"
    )
    send_record.campaign_variants.create!(
      name: winner.name,
      subject: winner.subject,
      body: winner.body,
      weight: 100,
      winner: true
    )
    CampaignSendJob.perform_later(send_record.id)
    redirect_to @campaign, notice: t("flashes.campaigns.winner_send_queued", count: remaining.size)
  end

  def recipient_count
    authorize @campaign, :show?
    segment = current_workspace.segments.find(params[:segment_id])
    count = (segment.record_type == "Person") ? segment.resolve(current_workspace.people).count : 0
    render json: {count: count}
  end

  private

  def campaign_stats
    messages = @campaign.email_messages.where(marketing_send: true)
    {
      sent: messages.count,
      opened: messages.where.not(opened_at: nil).count,
      clicked: messages.where("clicks_count > 0").count
    }
  end

  def resolve_subscription_type
    SubscriptionType.ensure_defaults!(current_workspace)
    if params[:subscription_type_id].present?
      current_workspace.subscription_types.find(params[:subscription_type_id])
    else
      current_workspace.subscription_types.find_by(slug: "newsletter")
    end
  end

  def create_test_person!(email)
    company = current_workspace.companies.find_or_create_by!(name: LeadForm::PLACEHOLDER_COMPANY_NAME)
    current_workspace.people.create!(first_name: "Prueba", last_name: "Marketing", email: email, company: company)
  end

  def build_test_variant(email_content)
    return nil if params[:variant_a_subject].blank?

    {
      subject: params[:variant_a_subject],
      body: params[:variant_a_body].presence || email_content.default_body
    }
  end

  def create_variants!(send_record)
    return if params[:variant_a_subject].blank?

    default_body = @campaign.email_content.default_body
    send_record.campaign_variants.create!(
      name: "A",
      subject: params[:variant_a_subject],
      body: params[:variant_a_body].presence || default_body,
      weight: params[:variant_a_weight].presence || 50
    )
    send_record.campaign_variants.create!(
      name: "B",
      subject: params[:variant_b_subject],
      body: params[:variant_b_body].presence || default_body,
      weight: params[:variant_b_weight].presence || 50
    )
  end

  def load_email_form_collections
    @email_templates = current_workspace.email_templates.ordered
    @email_layouts = current_workspace.email_layouts.ordered
  end

  def set_campaign
    @campaign = policy_scope(current_workspace.campaigns).find(params[:id])
  end

  def campaign_params
    permitted = params.require(:campaign).permit(
      :name, :status, :starts_on, :goal,
      :utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content,
      :email_template_id, :email_layout_id, :email_subject, :email_body, :email_body_editor
    )
    if permitted.key?(:email_template_id) && permitted[:email_template_id].present?
      permitted[:email_template_id] = resolve_email_template_id(permitted[:email_template_id])
    end
    if permitted.key?(:email_layout_id) && permitted[:email_layout_id].present?
      permitted[:email_layout_id] = resolve_email_layout_id(permitted[:email_layout_id])
    end
    permitted
  end
end
