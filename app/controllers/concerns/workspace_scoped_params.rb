# Resolves foreign-key params within the current workspace (raises RecordNotFound if cross-tenant).
module WorkspaceScopedParams
  extend ActiveSupport::Concern

  private

  def resolve_workspace_company_id(raw_id)
    return nil if raw_id.blank?

    current_workspace.companies.find(raw_id).id
  end

  def resolve_workspace_user_id(raw_id)
    return nil if raw_id.blank?

    current_workspace.users.find(raw_id).id
  end

  def resolve_workspace_person_ids(ids)
    requested = Array(ids).reject(&:blank?).map(&:to_i).uniq
    return [] if requested.empty?

    allowed = policy_scope(current_workspace.people).where(id: requested).pluck(:id)
    return requested if allowed.size == requested.size

    raise ActiveRecord::RecordNotFound
  end

  def resolve_workspace_pipeline_attrs!(attrs)
    if attrs[:pipeline_id].present?
      attrs[:pipeline_id] = current_workspace.pipelines.find(attrs[:pipeline_id]).id
    end
    if attrs[:pipeline_stage_id].present?
      stage = current_workspace.pipeline_stages.find(attrs[:pipeline_stage_id])
      attrs[:pipeline_stage_id] = stage.id
      attrs[:pipeline_id] ||= stage.pipeline_id
    end
    attrs
  end

  def resolve_deal_scoped_params!(permitted)
    h = permitted.to_unsafe_h.deep_symbolize_keys
    h[:company_id] = resolve_workspace_company_id(h[:company_id]) if h.key?(:company_id)
    if h.key?(:partner_id)
      h[:partner_id] = h[:partner_id].present? ? resolve_workspace_company_id(h[:partner_id]) : nil
    end
    h[:owner_id] = resolve_workspace_user_id(h[:owner_id]) if h.key?(:owner_id)
    h[:contact_ids] = resolve_workspace_person_ids(h[:contact_ids]) if h.key?(:contact_ids)
    resolve_workspace_pipeline_attrs!(h)
    normalize_deal_products_attributes!(h[:deal_products_attributes]) if h[:deal_products_attributes].present?
    permitted.merge!(h.deep_stringify_keys)
    permitted
  end

  def normalize_deal_products_attributes!(lines)
    return if lines.blank?

    collection = if lines.is_a?(Hash)
      lines.values
    else
      Array(lines)
    end
    collection.each do |line|
      next if line.blank?

      raw = line.is_a?(ActionController::Parameters) ? line.to_unsafe_h : line.to_h
      product_id = raw["product_id"] || raw[:product_id]
      next if product_id.blank?

      found = current_workspace.products.find(product_id).id
      if line.is_a?(ActionController::Parameters)
        line[:product_id] = found
      else
        raw["product_id"] = found
        line.replace(raw) if line.respond_to?(:replace)
      end
    end
  end

  def resolve_person_scoped_params!(permitted)
    h = permitted.to_unsafe_h.deep_symbolize_keys
    if h.key?(:company_id) && h[:company_id].present?
      h[:company_id] = resolve_workspace_company_id(h[:company_id])
    end
    h[:owner_id] = resolve_workspace_user_id(h[:owner_id]) if h.key?(:owner_id)
    if h.key?(:brought_by_id) && h[:brought_by_id].present?
      h[:brought_by_id] = resolve_workspace_user_id(h[:brought_by_id])
    end
    permitted.merge!(h.deep_stringify_keys)
    permitted
  end

  def resolve_task_scoped_params!(permitted)
    h = permitted.to_unsafe_h.deep_symbolize_keys
    if h.key?(:assignee_id)
      h[:assignee_id] = h[:assignee_id].present? ? resolve_workspace_user_id(h[:assignee_id]) : nil
    end
    permitted.merge!(h.deep_stringify_keys)
    permitted
  end

  def resolve_email_template_id(raw_id)
    return nil if raw_id.blank?

    current_workspace.email_templates.find(raw_id).id
  end

  def resolve_email_layout_id(raw_id)
    return nil if raw_id.blank?

    current_workspace.email_layouts.find(raw_id).id
  end
end
