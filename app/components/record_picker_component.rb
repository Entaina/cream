# frozen_string_literal: true

# Searchable combobox for picking a record (company, person, etc.) inside a form.
# Embeds the full candidate list when +scope+ has at most INLINE_LIMIT rows; otherwise
# searches remotely via +search_url+.
class RecordPickerComponent < ViewComponent::Base
  INLINE_LIMIT = 200

  attr_reader :form, :attribute, :label, :scope, :search_url, :create_url, :create_param,
              :selected_name, :required, :hidden_data, :name_method, :hint_method, :disabled

  def initialize(form:, attribute:, label:, scope:, search_url:, create_url: nil, create_param: nil,
                 selected_name: nil, required: false, hidden_data: {}, name_method: :name, hint_method: nil,
                 disabled: false)
    @form = form
    @attribute = attribute
    @label = label
    @scope = scope
    @search_url = search_url
    @create_url = create_url
    @create_param = create_param
    @selected_name = selected_name
    @required = required
    @hidden_data = hidden_data
    @name_method = name_method
    @hint_method = hint_method
    @disabled = disabled
  end

  def inline_records
    return if scope.nil?

    count = scope.count
    return if count.zero? || count > INLINE_LIMIT

    scope.map { |record| record_payload(record) }
  end

  def create_enabled?
    create_url.present? && create_param.present?
  end

  def inline_records_json
    ERB::Util.html_escape(inline_records.to_json) if inline_records
  end

  private

  def record_payload(record)
    hint = hint_method && record.respond_to?(hint_method) ? record.public_send(hint_method) : nil
    { id: record.id, name: record.public_send(name_method), hint: hint.presence }
  end
end
