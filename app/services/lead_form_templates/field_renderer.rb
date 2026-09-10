module LeadFormTemplates
  class FieldRenderer
    def initialize(view_context:, params:, open_editions: [])
      @view_context = view_context
      @params = params
      @open_editions = open_editions
    end

    def render(type:, name:, **options)
      html = case type.to_s
      when "text" then text_field(name, **options)
      when "email" then email_field(name, **options)
      when "tel" then telephone_field(name, **options)
      when "textarea" then textarea_field(name, **options)
      when "select" then select_field(name, **options)
      when "checkbox" then checkbox_field(name, **options)
      when "radio_group" then radio_group_field(name, **options)
      when "label" then field_label(name, **options)
      else
        ""
      end

      label = options[:text] || options[:label]
      return html if type.to_s.in?(%w[label checkbox radio_group]) || label.blank?

      <<~HTML
        <div>
          #{field_label(name, text: label, required: options[:required] == true)}
          #{html}
        </div>
      HTML
    end

    def field_label(name, text:, required: false, **)
      label_class = "label"
      required_marker = required ? required_marker_html : ""
      %(<label class="#{label_class}" for="lead_#{name}">#{ERB::Util.html_escape(text)}#{required_marker}</label>)
    end

    def text_field(name, required: false, autocomplete: nil, class_name: "input w-full", **)
      attrs = input_attrs(name, required: required, autocomplete: autocomplete, class_name: class_name, value: submitted_value(name))
      %(<input type="text" #{attrs} />)
    end

    def email_field(name, required: false, autocomplete: nil, class_name: "input w-full", **)
      attrs = input_attrs(name, required: required, autocomplete: autocomplete, class_name: class_name, value: submitted_value(name))
      %(<input type="email" #{attrs} />)
    end

    def telephone_field(name, required: false, autocomplete: nil, class_name: "input w-full", inputmode: nil, **)
      attrs = input_attrs(name, required: required, autocomplete: autocomplete, class_name: class_name, inputmode: inputmode, value: submitted_value(name))
      %(<input type="tel" #{attrs} />)
    end

    def textarea_field(name, required: false, rows: 4, placeholder: nil, class_name: "input w-full resize-y", **)
      attrs = []
      attrs << %(id="lead_#{name}")
      attrs << %(name="lead[#{name}]")
      attrs << %(class="#{class_name}")
      attrs << %(required="required") if required
      attrs << %(rows="#{rows}")
      attrs << %(placeholder="#{ERB::Util.html_escape(placeholder)}") if placeholder
      %(<textarea #{attrs.join(" ")}>#{ERB::Util.html_escape(submitted_value(name))}</textarea>)
    end

    def select_field(name, choices: nil, collection: nil, blank: nil, required: false, class_name: "input w-full", selected: nil, **)
      selected ||= submitted_value(name)
      option_tags = if collection.present?
        collection_options(collection, selected: selected)
      else
        option_tags_for(self.class.parse_choice_pairs(choices), blank: blank, selected: selected)
      end
      attrs = input_attrs(name, required: required, class_name: class_name, id: "lead_#{name}", type: nil)
      %(<select #{attrs}>#{option_tags}</select>)
    end

    def checkbox_field(name, label:, value: "1", unchecked_value: "0", class_name: "mt-0.5 rounded border-line", required: false, **)
      checkbox_id = "lead_#{name}"
      required_attr = required ? ' required="required"' : ""
      submitted = submitted_value(name)
      checked_attr = submitted.present? && submitted.to_s == value.to_s ? ' checked="checked"' : ""
      <<~HTML.squish
        <label class="flex items-start gap-2.5 text-sm text-ink-soft cursor-pointer">
          <input type="hidden" name="lead[#{name}]" value="#{unchecked_value}" autocomplete="off" />
          <input type="checkbox" name="lead[#{name}]" id="#{checkbox_id}" value="#{value}" class="#{class_name}"#{required_attr}#{checked_attr} />
          <span>#{ERB::Util.html_escape(label)}</span>
        </label>
      HTML
    end

    def radio_group_field(name, collection:, required: false, aria_label: nil, **)
      editions = resolve_collection(collection)
      selected = submitted_value(name)
      buttons = editions.map do |edition|
        checked = selected.to_s == edition.id.to_s
        checked_attr = checked ? ' checked="checked"' : ""
        <<~HTML
          <label class="cursor-pointer">
            <input type="radio" name="lead[#{name}]" value="#{edition.id}" required="#{required ? "required" : nil}" class="peer sr-only"#{checked_attr} />
            <span class="inline-flex items-center rounded-lg px-4 py-2 text-sm font-medium ring-1 ring-line-strong bg-canvas-raised text-ink-soft transition-colors peer-checked:bg-accent peer-checked:text-on-dark peer-checked:ring-accent hover:bg-canvas-soft peer-checked:hover:bg-accent-dark">
              #{ERB::Util.html_escape(edition.display_name)}
            </span>
          </label>
        HTML
      end.join

      aria = aria_label.present? ? %( aria-label="#{ERB::Util.html_escape(aria_label)}") : ""
      %(<div class="flex flex-wrap gap-2" role="radiogroup"#{aria}>#{buttons}</div>)
    end

    def phone_with_prefix(required: true, selected_prefix: "+34", prefixes: nil)
      prefix_options = option_tags_for(
        self.class.parse_choice_pairs(prefixes),
        blank: nil,
        selected: submitted_value(:phone_prefix).presence || selected_prefix
      )
      prefix_attrs = input_attrs(:phone_prefix, required: false, class_name: "input w-auto shrink-0", aria_label: "Prefijo de país")
      phone_attrs = input_attrs(:phone, required: required, class_name: "input w-full min-w-0", autocomplete: "tel-national", inputmode: "tel", value: submitted_value(:phone))
      <<~HTML
        <div class="flex gap-2">
          <select #{prefix_attrs}>#{prefix_options}</select>
          <input type="tel" #{phone_attrs} />
        </div>
      HTML
    end

    def hidden_fields(lead_form:, product:, privacy_policy_hash: nil, submission_key: nil)
      lines = []
      lines << hidden_input(LeadForm::TIMESTAMP_FIELD, LeadForm.signed_timestamp)
      lines << hidden_input("privacy_policy_hash", privacy_policy_hash) if privacy_policy_hash.present?
      lines << hidden_input("_submission_key", submission_key) if submission_key.present?
      lines << hidden_input("lead_form_slug", lead_form.slug)
      lines << hidden_input("lead_form_name", lead_form.name)
      lines << hidden_input("product_id", product.id) if product&.persisted?
      lines << hidden_input("source_page", @params[:source_page], data: { lead_form_target: "sourcePage" })
      lines << hidden_input("referrer", nil, data: { lead_form_target: "referrer" })
      %w[utm_source utm_medium utm_campaign utm_term utm_content].each do |key|
        lines << hidden_input(key, @params[key], data: { lead_form_target: key.camelize(:lower) })
      end
      lead_form.hidden_field_keys.each do |key|
        lines << hidden_input(key, @params[key], data: { lead_form_param: key })
      end
      lines.join
    end

    def honeypot_field
      name = LeadForm::HONEYPOT_FIELD
      <<~HTML
        <div class="hidden" aria-hidden="true">
          <label for="lead_#{name}">No rellenar</label>
          <input type="text" name="lead[#{name}]" id="lead_#{name}" tabindex="-1" autocomplete="off" />
        </div>
      HTML
    end

    def turnstile_field
      return "" unless TurnstileVerifier.enabled?

      <<~HTML
        <div class="cf-turnstile" data-sitekey="#{ERB::Util.html_escape(TurnstileVerifier.site_key)}" data-appearance="interaction-only"></div>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
      HTML
    end

    def submit_button(label = "Enviar")
      %(<div><input type="submit" value="#{ERB::Util.html_escape(label)}" class="btn-primary w-full" data-disable-with="#{ERB::Util.html_escape(label)}" /></div>)
    end

    def privacy_link(text:, url:, css: "text-accent hover:underline")
      %(<a href="#{ERB::Util.html_escape(url)}" target="_blank" rel="noopener" class="#{css}">#{ERB::Util.html_escape(text)}</a>)
    end

    def self.parse_choice_pairs(raw)
      return [] if raw.blank?

      raw.to_s.split(";").filter_map do |entry|
        entry = entry.strip
        next if entry.blank?

        if entry.include?("|")
          label, value = entry.split("|", 2).map(&:strip)
          next if label.blank? || value.blank?

          [ label, value ]
        else
          [ entry, entry ]
        end
      end
    end

    private

    def input_attrs(name, required: false, class_name: nil, autocomplete: nil, rows: nil, placeholder: nil, inputmode: nil, id: nil, type: "text", aria_label: nil, value: nil)
      attrs = []
      attrs << %(id="#{id || "lead_#{name}"}")
      attrs << %(name="lead[#{name}]")
      attrs << %(type="#{type}") if type
      attrs << %(value="#{ERB::Util.html_escape(value)}") if value.present?
      attrs << %(class="#{class_name}") if class_name
      attrs << %(required="required") if required
      attrs << %(autocomplete="#{autocomplete}") if autocomplete
      attrs << %(rows="#{rows}") if rows
      attrs << %(placeholder="#{ERB::Util.html_escape(placeholder)}") if placeholder
      attrs << %(inputmode="#{inputmode}") if inputmode
      attrs << %(aria-label="#{ERB::Util.html_escape(aria_label)}") if aria_label
      attrs.join(" ")
    end

    # What the visitor already typed, so a re-render (e.g. 422) keeps their input.
    def submitted_value(name)
      @params.dig(:lead, name) || @params.dig("lead", name.to_s)
    end

    def hidden_input(name, value, data: {})
      data_attrs = data.map { |key, val| %(data-#{key.to_s.dasherize}="#{ERB::Util.html_escape(val)}") }.join(" ")
      %(<input type="hidden" name="lead[#{name}]" id="lead_#{name}" value="#{ERB::Util.html_escape(value)}" autocomplete="off" #{data_attrs} />)
    end

    def option_tags_for(pairs, blank:, selected: nil)
      html = ""
      html << %(<option value="">#{ERB::Util.html_escape(blank)}</option>) if blank.present?
      pairs.each do |label, value|
        selected_attr = selected.to_s == value.to_s ? ' selected="selected"' : ""
        html << %(<option value="#{ERB::Util.html_escape(value)}"#{selected_attr}>#{ERB::Util.html_escape(label)}</option>)
      end
      html
    end

    def collection_options(collection_key, selected:)
      resolve_collection(collection_key).map do |item|
        selected_attr = selected.to_s == item.id.to_s ? ' selected="selected"' : ""
        %(<option value="#{item.id}"#{selected_attr}>#{ERB::Util.html_escape(item.display_name)}</option>)
      end.join
    end

    def resolve_collection(collection_key)
      case collection_key.to_s
      when "open_editions"
        Array(@open_editions)
      else
        []
      end
    end

    def required_marker_html
      %(<span class="text-red-600 dark:text-red-400" aria-hidden="true">*</span>)
    end
  end
end
