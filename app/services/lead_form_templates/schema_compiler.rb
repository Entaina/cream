module LeadFormTemplates
  class SchemaCompiler
    STUB_PRODUCT_ID = 1
    STUB_EDITION_ID = 1

    def self.compile(template:)
      new(template).compile
    end

    def initialize(template)
      @template = template
      @workspace = template.workspace
    end

    def compile
      base_names = field_names(collects_company: false, with_product: false)
      with_company_names = field_names(collects_company: true, with_product: false)
      full_fields = render_fields(collects_company: true, with_product: true).index_by(&:name)

      fields = full_fields.values.map do |field|
        field_to_hash(field).merge(
          "requires_collects_company" => with_company_names.include?(field.name) && !base_names.include?(field.name),
          "requires_open_editions" => field.name == "edition_id" && !with_company_names.include?("edition_id"),
          "requires_product" => field.name == "product_id" && !with_company_names.include?("product_id"),
          "dynamic_allowed_values" => ((field.name == "edition_id") ? "open_editions" : nil)
        )
      end

      {"fields" => fields}
    end

    private

    def field_names(collects_company:, with_product:)
      render_fields(collects_company: collects_company, with_product: with_product).map(&:name)
    end

    def render_fields(collects_company:, with_product:)
      html = FormHtmlRenderer.render_template(
        template: @template,
        lead_form: stub_lead_form(collects_company: collects_company),
        product: with_product ? stub_product : nil,
        open_editions: with_product ? [stub_edition] : []
      )
      HtmlSchema.parse(html).fields
    end

    def stub_lead_form(collects_company:)
      LeadForm.new(
        workspace: @workspace,
        slug: "schema-preview",
        name: "Schema preview",
        template_key: @template.template_key,
        collects_company: collects_company,
        hidden_field_keys: []
      )
    end

    def stub_product
      product = Product.new(id: STUB_PRODUCT_ID, name: "Schema product", price: 0, workspace: @workspace)
      product.define_singleton_method(:persisted?) { true }
      product
    end

    def stub_edition
      Edition.new(id: STUB_EDITION_ID, name: "Schema edition", product: stub_product, workspace: @workspace)
    end

    def field_to_hash(field)
      {
        "name" => field.name,
        "input_type" => field.input_type,
        "required" => field.required,
        "allowed_values" => field.allowed_values,
        "checkbox_value" => field.checkbox_value
      }
    end
  end
end
