class MailMergesController < ApplicationController
  include RequiresFeature

  requires_feature :mail_merge

  RECORD_TYPES = List::RECORD_TYPES

  Recipients = Data.define(:record_type, :record_ids)

  def new
    authorize current_workspace, :mail_merge?
    @record_type = params[:record_type].presence_in(RECORD_TYPES) || "Person"
    @templates = current_workspace.email_templates.visible_to(current_user).ordered
    @saved_views = policy_scope(current_workspace.saved_views).visible_to(current_user).ordered
    @lists = current_workspace.lists.order(:name)
  end

  def create
    authorize current_workspace, :mail_merge?
    recipients = resolve_recipients

    if recipients.record_ids.empty?
      redirect_to mail_merge_path(record_type: recipients.record_type), alert: t("flashes.mail_merges.no_recipients")
      return
    end

    MailMergeJob.perform_later(
      current_workspace.id,
      current_user.id,
      recipients.record_type,
      recipients.record_ids,
      params[:subject],
      params[:body],
      resolved_mail_merge_template_id
    )

    redirect_to mail_merge_path(record_type: recipients.record_type),
      notice: t("flashes.mail_merges.queued", count: recipients.record_ids.size)
  end

  # Live recipient count for the picker (fetched by the form via JS).
  def recipients_count
    authorize current_workspace, :mail_merge?
    recipients = resolve_recipients
    render json: {count: recipients.record_ids.size, record_type: recipients.record_type}
  end

  private

  # Resolves the chosen source into a (record_type, record_ids) pair. The source
  # is "view:<id>", "list:<id>" or "manual" — for views/lists the record type is
  # derived from the source itself, so it can't drift from the dropdown.
  def resolve_recipients
    case params[:source].to_s
    when /\Aview:(\d+)\z/
      view = policy_scope(current_workspace.saved_views).visible_to(current_user).find(Regexp.last_match(1))
      base = policy_scope(current_workspace.public_send(view.record_type.tableize))
      Recipients.new(view.record_type, view.resolve(base).pluck(:id).map(&:to_s))
    when /\Alist:(\d+)\z/
      list = current_workspace.lists.find(Regexp.last_match(1))
      ids = list.list_entries.where(record_type: list.record_type).pluck(:record_id).map(&:to_s)
      ids = visible_record_ids(list.record_type, ids)
      Recipients.new(list.record_type, ids)
    else
      record_type = params[:record_type].presence_in(RECORD_TYPES) || "Person"
      ids = params[:record_ids].to_s.split(",").map(&:strip).reject(&:blank?)
      ids = visible_record_ids(record_type, ids)
      Recipients.new(record_type, ids)
    end
  end

  def visible_record_ids(record_type, ids)
    return [] if ids.empty?

    policy_scope(current_workspace.public_send(record_type.tableize))
      .where(id: ids)
      .pluck(:id)
      .map(&:to_s)
  end

  def resolved_mail_merge_template_id
    raw_id = params[:template_id].presence
    return nil if raw_id.blank?

    current_workspace.email_templates.visible_to(current_user).find(raw_id).id
  end
end
