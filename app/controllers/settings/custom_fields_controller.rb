module Settings
  class CustomFieldsController < ApplicationController
    include RequiresFeature

    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized
    after_action :verify_policy_scoped, only: :index

    requires_workspace_feature :custom_fields

    before_action :set_custom_field, only: %i[edit update destroy]

    def index
      authorize [ :settings, CustomField ]
      @fields_by_type = policy_scope([ :settings, CustomField ]).ordered.group_by(&:record_type)
      @admin = pundit_user.admin?
    end

    def new
      @custom_field = current_workspace.custom_fields.new(record_type: params[:record_type] || "Person")
      authorize [ :settings, @custom_field ]
    end

    def create
      @custom_field = current_workspace.custom_fields.new(custom_field_params)
      authorize [ :settings, @custom_field ]

      if @custom_field.save
        redirect_to settings_custom_fields_path, notice: "Custom field created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :settings, @custom_field ]
    end

    def update
      authorize [ :settings, @custom_field ]

      if @custom_field.update(custom_field_params)
        redirect_to settings_custom_fields_path, notice: "Custom field updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [ :settings, @custom_field ]
      @custom_field.destroy
      redirect_to settings_custom_fields_path, notice: "Custom field deleted.", status: :see_other
    end

    private

    def set_custom_field
      @custom_field = policy_scope([ :settings, CustomField ]).find(params[:id])
    end

    def custom_field_params
      permitted = params.require(:custom_field).permit(:name, :record_type, :field_type, :required, :options_text, :formula_expression, :reference_type)
      attrs = permitted.except(:options_text)
      attrs[:options] = parse_options(permitted[:options_text]) if permitted.key?(:options_text)
      attrs
    end

    def parse_options(text)
      text.to_s.lines.map(&:strip).reject(&:blank?)
    end
  end
end
