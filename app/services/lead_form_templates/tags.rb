module LeadFormTemplates
  module Tags
    class BaseTag < Liquid::Tag
      private

      def renderer(context)
        context.registers[:field_renderer]
      end

      def template_renderer(context)
        context.registers[:template_renderer]
      end

      def parse_attributes(markup)
        attributes = {}
        markup.scan(/(\w+)\s*:\s*(["'])(.*?)\2/) do |key, _, value|
          attributes[key] = value
        end
        markup.scan(/(\w+)\s*:\s*(true|false)\b/) do |key, value|
          attributes[key] = value == "true"
        end
        attributes
      end
    end

    class PartialTag < BaseTag
      def initialize(tag_name, markup, parse_context)
        super
        @path = markup.to_s.strip.delete_prefix('"').delete_prefix("'").delete_suffix('"').delete_suffix("'")
      end

      def render(context)
        template_renderer(context).render(resolve_path(context))
      end

      private

      def resolve_path(_context)
        path = @path
        return path if path.start_with?("public/lead_forms/")

        "public/lead_forms/partials/#{path}"
      end
    end

    class FieldTag < BaseTag
      def initialize(tag_name, markup, parse_context)
        super
        @attributes = parse_attributes(markup)
      end

      def render(context)
        type = @attributes.fetch("type")
        name = @attributes.fetch("name")
        renderer(context).render(
          type: type,
          name: name.to_sym,
          text: @attributes["label"],
          choices: @attributes["choices"],
          collection: @attributes["collection"],
          blank: @attributes["blank"],
          required: @attributes["required"] == true,
          autocomplete: @attributes["autocomplete"],
          rows: @attributes["rows"]&.to_i,
          placeholder: @attributes["placeholder"],
          label: @attributes["label"],
          value: @attributes["value"],
          unchecked_value: @attributes["unchecked_value"],
          aria_label: @attributes["aria_label"],
          class_name: @attributes["class"] || default_class(type)
        )
      end

      private

      def default_class(type)
        case type
        when "checkbox" then "mt-0.5 rounded border-line"
        else "input w-full"
        end
      end
    end

    class PhoneWithPrefixTag < BaseTag
      def initialize(tag_name, markup, parse_context)
        super
        @attributes = parse_attributes(markup)
      end

      def render(context)
        renderer(context).phone_with_prefix(
          required: @attributes.fetch("required", true),
          selected_prefix: @attributes.fetch("prefix", "+34"),
          prefixes: @attributes["prefixes"]
        )
      end
    end

    class FormOpenTag < BaseTag
      def render(context)
        lead_form = context.registers[:lead_form]
        # Con redirección tras envío, el formulario tiene que poder sacar al visitante del
        # iframe cuando está empotrado en otra web. target="_top" solo no basta: Turbo
        # intercepta el submit y lo manda por fetch, ignorando el target, así que el lead
        # se crea pero nadie llega al destino. data-turbo="false" devuelve el envío al
        # navegador, que sí respeta el target.
        target = lead_form.success_redirect_url.present? ? ' target="_top" data-turbo="false"' : ""
        corporate_attrs = corporate_email_form_attrs(lead_form)
        <<~HTML
          <form action="#{context.registers[:form_action]}" method="post" class="space-y-4" data-controller="lead-form"#{target}#{corporate_attrs[:form_suffix]}>
            #{inline_alert(context.registers[:flash_alert])}
            <div data-lead-form-target="corporateEmailAlert" class="hidden rounded-lg bg-danger-soft text-danger-strong ring-1 ring-danger-line px-4 py-3 text-sm" role="alert"></div>
            <input type="hidden" name="authenticity_token" value="#{ERB::Util.html_escape(context.registers[:csrf_token])}" autocomplete="off" />
        HTML
      end

      private

      def corporate_email_form_attrs(lead_form)
        return {form_suffix: ""} unless lead_form.require_corporate_email?

        domains_json = ERB::Util.html_escape(LeadForms::FreeEmailDomain.domains.to_a.to_json)
        message = ERB::Util.html_escape(I18n.t("lead_forms.corporate_email_required"))
        form_suffix = %( data-lead-form-require-corporate-email-value="true" data-lead-form-blocked-domains-value="#{domains_json}" data-lead-form-corporate-email-message-value="#{message}" data-action="submit->lead-form#validateCorporateEmail input->lead-form#clearCorporateEmailError")
        {form_suffix: form_suffix}
      end

      # Persistent error notice inside the form: the floating flash auto-hides,
      # so on a 422 re-render the visitor needs a message that stays put.
      def inline_alert(message)
        return "" if message.blank?

        %(<div class="rounded-lg bg-danger-soft text-danger-strong ring-1 ring-danger-line px-4 py-3 text-sm" role="alert">#{ERB::Util.html_escape(message)}</div>)
      end
    end

    class FormCloseTag < BaseTag
      def render(_context)
        "</form>"
      end
    end

    class HiddenFieldsTag < BaseTag
      def render(context)
        renderer(context).hidden_fields(
          lead_form: context.registers[:lead_form],
          product: context.registers[:product],
          privacy_policy_hash: context.registers[:privacy_policy_hash],
          submission_key: context.registers[:submission_key]
        )
      end
    end

    class HoneypotTag < BaseTag
      def render(context)
        renderer(context).honeypot_field
      end
    end

    class TurnstileTag < BaseTag
      def render(context)
        renderer(context).turnstile_field
      end
    end

    class SubmitTag < BaseTag
      def initialize(tag_name, markup, parse_context)
        super
        @label = markup.to_s.strip.presence || "Enviar"
        @label = @label.delete_prefix('"').delete_prefix("'").delete_suffix('"').delete_suffix("'")
      end

      def render(context)
        renderer(context).submit_button(@label)
      end
    end

    class PrivacyLinkTag < BaseTag
      def initialize(tag_name, markup, parse_context)
        super
        @attributes = parse_attributes(markup)
      end

      def render(context)
        url = @attributes["url"] || context.registers[:privacy_url]
        renderer(context).privacy_link(text: @attributes.fetch("text"), url: url)
      end
    end

    class RequiredMarkerTag < BaseTag
      def render(_context)
        %(<span class="text-red-600 dark:text-red-400" aria-hidden="true">*</span>)
      end
    end

    class SubscriptionOptInAllTag < BaseTag
      def initialize(tag_name, markup, parse_context)
        super
        @attributes = parse_attributes(markup)
      end

      def render(context)
        return "" unless CreamFeatures.enabled?(:marketing_consent)

        lead_form = context.registers[:lead_form]
        tag_exclude_slugs = parse_exclude_slugs(@attributes["exclude"])
        active_types = Marketing::ConsentService.subscribe_all_types_for(
          lead_form.workspace,
          additional_exclude_slugs: tag_exclude_slugs
        )
        return "" if active_types.empty?

        label = @attributes["label"].presence ||
          Marketing::ConsentService.subscribe_all_default_label(active_types)
        field_key = Marketing::ConsentService::SUBSCRIBE_ALL_FIELD_KEY

        checkbox = renderer(context).render(
          type: "checkbox",
          name: field_key.to_sym,
          label: label
        )
        hidden_fields = %(<input type="hidden" name="lead[subscribe_all_label]" value="#{ERB::Util.html_escape(label)}" />)
        if tag_exclude_slugs.any?
          hidden_fields += %(<input type="hidden" name="lead[subscribe_all_exclude_slugs]" value="#{ERB::Util.html_escape(tag_exclude_slugs.join(","))}" />)
        end

        checkbox + hidden_fields
      end

      private

      def parse_exclude_slugs(value)
        return [] if value.blank?

        value.to_s.split(",").map { |slug| slug.strip }.reject(&:blank?)
      end
    end

    class SubscriptionOptInTag < BaseTag
      def initialize(tag_name, markup, parse_context)
        super
        @attributes = parse_attributes(markup)
      end

      def render(context)
        lead_form = context.registers[:lead_form]
        slug = @attributes.fetch("slug")
        subscription_type = lead_form.workspace.subscription_types.active.find_by(slug: slug)
        field_key = subscription_type && Marketing::ConsentService.field_key_for(subscription_type)
        return "" if field_key.blank?

        label = @attributes["label"].presence ||
          primary_consent_label(lead_form, subscription_type) ||
          subscription_type.default_consent_label.presence ||
          subscription_type.name

        renderer(context).render(
          type: "checkbox",
          name: field_key.to_sym,
          label: label
        )
      end

      private

      def primary_consent_label(lead_form, subscription_type)
        return unless lead_form.mql_subscription_type&.id == subscription_type.id

        lead_form.marketing_consent_text.presence
      end
    end

    REGISTRY = {
      "partial" => PartialTag,
      "field" => FieldTag,
      "phone_with_prefix" => PhoneWithPrefixTag,
      "form_open" => FormOpenTag,
      "form_close" => FormCloseTag,
      "hidden_fields" => HiddenFieldsTag,
      "honeypot" => HoneypotTag,
      "turnstile" => TurnstileTag,
      "submit" => SubmitTag,
      "privacy_link" => PrivacyLinkTag,
      "required_marker" => RequiredMarkerTag,
      "subscription_opt_in" => SubscriptionOptInTag,
      "subscription_opt_in_all" => SubscriptionOptInAllTag
    }.freeze
  end
end
