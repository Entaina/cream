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
        target = lead_form.success_redirect_url.present? ? ' target="_top"' : ""
        <<~HTML
          <form action="#{context.registers[:form_action]}" method="post" class="space-y-4" data-controller="lead-form"#{target}>
            <input type="hidden" name="authenticity_token" value="#{ERB::Util.html_escape(context.registers[:csrf_token])}" autocomplete="off" />
        HTML
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
          product: context.registers[:product]
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
      "required_marker" => RequiredMarkerTag
    }.freeze
  end
end
