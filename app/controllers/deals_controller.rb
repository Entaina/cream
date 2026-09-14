class DealsController < ApplicationController
  include ViewScoped
  include Filterable

  remembers_list_filters only: %i[index board]

  before_action :set_deal, only: %i[show edit update destroy move move_pipeline duplicate]
  before_action :set_edit_section, only: %i[edit update]

  SORTABLE = %w[name value expected_close_date invoice_number created_at].freeze

  def index
    load_saved_views("Deal")
    @pipeline_filter = resolve_pipeline_filter
    if params.key?(:pipeline_id)
      @effective_filters = @effective_filters.merge(pipeline_id: pipeline_id_filter_value)
    end
    @deals = apply_pipeline_scope(
      filtered_deals(
        policy_scope(current_workspace.deals).includes(:company, :owner, :pipeline, :pipeline_stage, :contacts, custom_field_values: :custom_field)
      )
    )
    @display_pipeline = pipeline_for_display
    @deals = if filter_value(:sort) == "stage" && @display_pipeline
      @deals.sorted_by_stage_order(filter_value(:dir) == "desc" ? :desc : :asc)
    else
      apply_sorting(@deals, sortable: SORTABLE, default_column: "created_at")
    end
    @pagy, @deals = pagy(:offset, @deals)
    load_deal_filter_options
    @custom_fields = current_workspace.custom_fields.where(record_type: "Deal").ordered
  end

  # JSON search behind the "link payment to deal" picker: open + won deals
  # (lost excluded), filtered by name/company, newest first.
  def picker
    authorize Deal, :index?
    deals = policy_scope(current_workspace.deals).linkable
      .search(params[:q])
      .includes(:company, :pipeline_stage)
      .order(created_at: :desc)
      .limit(20)
    render json: deals.map { |deal|
      {
        id: deal.id,
        name: deal.name,
        company: deal.company&.name,
        stage: deal.stage_label,
        won: deal.pipeline_stage.won?,
        value: helpers.money(deal.value, deal.currency)
      }
    }
  end

  def board
    authorize Deal, :board?
    load_saved_views("Deal")
    @effective_filters = @effective_filters.except(:stage)
    @pipelines = current_workspace.pipelines.ordered.includes(:pipeline_stages)
    @pipeline = current_pipeline
    if @pipeline
      @effective_filters = @effective_filters.merge(pipeline_id: @pipeline.id)
    end
    includes = [ :company, :owner, :pipeline, { tasks: :assignee } ]
    if @pipeline
      includes << :contacts if @pipeline.show_card_field?(:contacts)
      includes << { deal_products: [ :product, :edition ] } if @pipeline.show_card_field?(:products)
    else
      includes << :contacts if @pipelines.any? { |pipeline| pipeline.show_card_field?(:contacts) }
      if @pipelines.any? { |pipeline| pipeline.show_card_field?(:products) }
        includes << { deal_products: [ :product, :edition ] }
      end
    end
    deals = filtered_deals(policy_scope(current_workspace.deals).includes(*includes))
    deals = deals.where(pipeline_id: @pipeline.id) if @pipeline
    stages = if @pipeline
      @pipeline.pipeline_stages.ordered.to_a
    else
      current_workspace.pipeline_stages.ordered_across_pipelines.to_a
    end
    stages = stages.reject(&:closed?) unless show_closed?
    @board_all_pipelines = @pipeline.nil?
    @board_stage_columns = build_board_stage_columns(stages, deals)
    load_deal_filter_options
  end

  def show
    authorize @deal
    @deal_tab = params[:tab].presence_in(%w[activity pipeline products information files]) || "activity"
    @deal_tab = "activity" if @deal_tab == "files" && !CreamFeatures.enabled?(:attachments)
    @pending_tasks = @deal.tasks.pending.includes(:assignee).due_order
    @completed_tasks = @deal.tasks.completed.includes(:assignee).order(completed_at: :desc)
    @activity_feed = RecordActivityFeed.new(@deal, filter: params[:activity_filter], page: params[:activity_page],
      emails: CreamFeatures.enabled?(:record_email), comments: CreamFeatures.enabled?(:comments))
    @okm_chat_record = @deal
    @line_items = @deal.deal_products.includes(:product, :edition)
    @products = current_workspace.products.ordered
    @note = Note.new
    @comment = Comment.new
    @email_message = EmailMessage.new(to_address: @deal.contacts.first&.email)
    @task = Task.new(due_on: Task.default_due_on)
  end

  def new
    pipeline = Pipeline.default_for(current_workspace)
    @deal = current_workspace.deals.new(company_id: params[:company_id],
      pipeline: pipeline, pipeline_stage: pipeline&.first_stage, owner: current_user)
    @deal.contact_ids = [ params[:person_id] ] if params[:person_id].present?
    @deal.tasks.build(due_on: Task.default_due_on)
    prefill_from_stripe_payment
    authorize @deal
  end

  def create
    @deal = current_workspace.deals.new(deal_params)
    apply_quick_deal_from_person! if quick_from_person?
    authorize @deal
    @deal.owner ||= current_user

    if @deal.save
      link_stripe_payment(@deal)
      redirect_to @deal, notice: "Deal created."
    elsif quick_from_person?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            ActionView::RecordIdentifier.dom_id(quick_from_person, :quick_deal_form),
            partial: "people/quick_deal_form",
            locals: { person: quick_from_person, deal: @deal }
          ), status: :unprocessable_entity
        end
        format.html do
          redirect_to person_path(quick_from_person), alert: @deal.errors.full_messages.to_sentence
        end
      end
    else
      @stripe_payment = pending_stripe_payment
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @deal
  end

  def update
    authorize @deal
    attrs = deal_params
    new_stage = extract_stage_change(attrs)
    original_stage_id = @deal.pipeline_stage_id
    Deal.transaction do
      @deal.update!(attrs)
      @deal.move_to_stage!(new_stage) if new_stage
    end
    redirect_to @edit_section ? deal_path(@deal, tab: "information") : @deal, notice: "Deal updated."
  rescue ActiveRecord::RecordInvalid
    unless @edit_section
      @deal.reload
      @deal.pipeline_stage_id = original_stage_id if original_stage_id
    end
    flash.now[:alert] = @deal.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end

  def destroy
    authorize @deal
    @deal.destroy
    redirect_to board_deals_path, notice: "Deal deleted.", status: :see_other
  end

  def duplicate
    copy = @deal.duplicate
    authorize copy, :create?
    copy.owner ||= current_user
    if copy.save
      redirect_to copy, notice: "Deal duplicado."
    else
      redirect_to @deal, alert: copy.errors.full_messages.to_sentence
    end
  end

  # Kanban drag & drop target.
  def move
    authorize @deal, :move?
    @board_move_from_stage_name = @deal.pipeline_stage&.name
    @deal.move_to_stage!(params.require(:pipeline_stage_id), position: params[:position]&.to_i)

    respond_to do |format|
      format.turbo_stream { render_move_success_streams }
      format.json { head :ok }
      format.html do
        if params[:source] == "show"
          redirect_to @deal
        else
          redirect_to board_deals_path
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to_stage_move_error(e.record.errors.full_messages.to_sentence)
  end

  # Move the deal to another pipeline (lands on the destination's initial stage).
  def move_pipeline
    authorize @deal, :move?
    @deal.move_to_pipeline!(params.require(:pipeline_id))
    redirect_to @deal, notice: "Deal moved to pipeline #{@deal.pipeline.name}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @deal, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_edit_section
    @edit_section = params[:section].presence_in(%w[overview relationships management custom])
  end

  def filtered_deals(scope)
    scope = Deal.filter_by(scope, @effective_filters)
    scope = scope.open_deals unless show_closed?
    if params[:utm_source].present?
      scope = scope.left_joins(:campaign).where(campaigns: { utm_source: params[:utm_source] })
    end
    scope = scope.merge(Deal.apply_custom_field_filters(current_workspace, filter_value(:cf))) if filter_value(:cf).present?
    scope
  end

  def load_deal_filter_options
    @pipelines = current_workspace.pipelines.ordered.includes(:pipeline_stages)
    @products = current_workspace.products.ordered
    @edition_groups = @products.includes(:editions).filter_map do |product|
      options = product.editions.ordered.map { |edition| [ edition.name, edition.id ] }
      next if options.empty?

      [ product.name, options ]
    end
    @owners = current_workspace.users.order(:name)
  end

  def resolve_pipeline_filter
    if params.key?(:pipeline_id)
      return :all if params[:pipeline_id] == "all"

      id = params[:pipeline_id].to_i
      return id if params[:pipeline_id].present? && current_workspace.pipelines.exists?(id: id)

      nil
    elsif current_pipeline
      current_pipeline.id
    end
  end

  def pipeline_filter_applied?
    @pipeline_filter.present? && @pipeline_filter != :all
  end

  def pipeline_for_display
    return nil if @pipeline_filter == :all

    id = pipeline_filter_applied? ? @pipeline_filter : current_pipeline&.id
    current_workspace.pipelines.find_by(id: id) if id
  end

  def apply_pipeline_scope(scope)
    return scope if @pipeline_filter == :all
    return scope.where(pipeline_id: @pipeline_filter) if pipeline_filter_applied?

    scope
  end

  def pipeline_id_filter_value
    @pipeline_filter == :all ? "all" : @pipeline_filter
  end

  def set_deal
    @deal = policy_scope(current_workspace.deals)
      .includes(lead_submissions: [ :lead_form, :person, :privacy_policy_version ])
      .find(params[:id])
  end

  def deal_params
    params.require(:deal).permit(:name, :pipeline_id, :pipeline_stage_id, :value, :currency, :probability,
      :expected_close_date, :invoice_number, :company_id, :partner_id, :owner_id,
      contact_ids: [], tasks_attributes: %i[title due_on], custom_fields: {},
      deal_products_attributes: %i[id product_id edition_id edition_name quantity unit_price _destroy])
  end

  def quick_from_person?
    params[:quick_from_person_id].present?
  end

  def quick_from_person
    @quick_from_person ||= policy_scope(current_workspace.people).find(params[:quick_from_person_id])
  end

  def apply_quick_deal_from_person!
    person = quick_from_person
    pipeline = current_workspace.pipelines.find_by(id: @deal.pipeline_id) ||
      current_pipeline ||
      Pipeline.default_for(current_workspace)
    @deal.company = person.company
    @deal.contact_ids = [ person.id ]
    @deal.pipeline = pipeline
    @deal.pipeline_stage = pipeline&.first_stage
    @deal.name = quick_deal_name(person)
  end

  def quick_deal_name(person)
    line = @deal.deal_products.reject(&:marked_for_destruction?).first
    product_name = if line&.product
      line.product.name
    elsif line&.product_id.present?
      current_workspace.products.find_by(id: line.product_id)&.name
    end
    [ person.company.name, product_name ].compact_blank.join(" — ")
  end

  # "Create deal" from the Stripe payments inbox: prefill the form from the
  # payment, and reconcile the payment once the deal is saved.
  def prefill_from_stripe_payment
    @stripe_payment = pending_stripe_payment
    return unless @stripe_payment

    @deal.name = [ @stripe_payment.customer_name.presence || @stripe_payment.customer_email,
      @stripe_payment.description ].compact_blank.join(" — ") if @deal.name.blank?
    if @deal.company_id.blank? && @stripe_payment.suggested_person
      @deal.company_id = @stripe_payment.suggested_person.company_id
      @deal.contact_ids = [ @stripe_payment.suggested_person_id ] if @deal.contact_ids.empty?
    end
  end

  def link_stripe_payment(deal)
    payment = pending_stripe_payment
    payment&.match!(deal, user: current_user)
  end

  def pending_stripe_payment
    return nil if params[:stripe_payment_id].blank?
    return nil unless CreamFeatures.enabled?(:stripe_payments)

    current_workspace.stripe_payments.pending_review.find_by(id: params[:stripe_payment_id])
  end

  # Stage changes must go through move_to_stage! so the stage_changed activity,
  # webhooks, automations and stage triggers fire. Strips the stage (and the
  # pipeline, which move_to_stage! derives from the stage) from the direct
  # update and returns the target stage, or nil when the stage doesn't change.
  def extract_stage_change(attrs)
    stage_id = attrs[:pipeline_stage_id].presence
    return nil if stage_id.nil? || stage_id.to_i == @deal.pipeline_stage_id

    attrs.delete(:pipeline_stage_id)
    attrs.delete(:pipeline_id)
    current_workspace.pipeline_stages.find(stage_id)
  end

  def render_move_success_streams
    if params[:source] == "show"
      render turbo_stream: [
        turbo_stream.replace("deal_stage_badge", partial: "deals/stage_badge", locals: { deal: @deal }),
        turbo_stream.replace("deal_stage_stepper", partial: "deals/stage_stepper", locals: { deal: @deal }),
        turbo_stream.replace("deal_value_display_#{@deal.id}", partial: "deals/value_display", locals: { deal: @deal })
      ]
    else
      deals = board_move_deals_scope
      streams = board_move_summary_streams(deals)
      streams << turbo_stream.replace("deal_card_value_#{@deal.id}",
        partial: "deals/card_value", locals: { deal: @deal })
      render turbo_stream: streams
    end
  end

  def board_move_deals_scope
    scope = policy_scope(current_workspace.deals).includes(:pipeline, :pipeline_stage)
    scope = scope.where(pipeline_id: current_pipeline.id) if current_pipeline
    scope = scope.open_deals unless show_closed?
    scope
  end

  def board_move_summary_streams(deals)
    if current_pipeline
      stages = board_move_stages
      stages.map { |stage|
        turbo_stream.replace("stage_summary_#{stage.id}",
          partial: "deals/stage_summary",
          locals: { stage: stage, deals: deals.by_stage(stage.id), reorderable: true })
      }
    else
      stage_names = [ @board_move_from_stage_name, @deal.pipeline_stage&.name ].compact.uniq
      grouper = StageNameGroup.new(board_move_stages)
      stage_names.filter_map { |name|
        group = grouper.groups.find { |entry| entry.name == name }
        next unless group

        group_deals = group.stages.flat_map { |stage| deals.by_stage(stage.id) }
        turbo_stream.replace(helpers.stage_summary_dom_id(name),
          partial: "deals/stage_summary",
          locals: { stage_name: name, dom_id: helpers.stage_summary_dom_id(name),
            stage: group.representative_stage, deals: group_deals,
            reorderable: false, show_probability: false })
      }
    end
  end

  def board_move_stages
    stages = if current_pipeline
      current_pipeline.pipeline_stages.ordered.to_a
    else
      current_workspace.pipeline_stages.ordered_across_pipelines.to_a
    end
    visible = show_closed? ? stages : stages.reject(&:closed?)
    [ @deal.pipeline_stage, *visible ].compact.uniq(&:id)
  end

  def build_board_stage_columns(stages, deals)
    if @board_all_pipelines
      StageNameGroup.group(stages).map do |group|
        {
          dom_id: helpers.stage_summary_dom_id(group.name),
          drop_key: group.name,
          name: group.name,
          color: group.stage_color,
          stage: group.representative_stage,
          deals: group.stages.flat_map { |stage| deals.by_stage(stage.id) },
          reorderable: false,
          show_pipeline_on_cards: true,
          show_probability: false
        }
      end
    else
      stages.map do |stage|
        {
          dom_id: "stage_summary_#{stage.id}",
          drop_key: stage.id,
          name: stage.name,
          color: stage.color,
          stage: stage,
          deals: deals.by_stage(stage.id),
          reorderable: true,
          show_pipeline_on_cards: false,
          show_probability: true
        }
      end
    end
  end

  def respond_to_stage_move_error(message)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("toasts",
          partial: "shared/toast", locals: { message: message, kind: "alert" }),
          status: :unprocessable_entity
      end
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html { redirect_back fallback_location: board_deals_path, alert: message }
    end
  end
end
