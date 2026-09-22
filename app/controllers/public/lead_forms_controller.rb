module Public
  class LeadFormsController < ApplicationController
    layout "public_lead_form"

    allow_unauthenticated_access only: %i[show create success privacy]
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :ensure_feature_enabled
    before_action :set_lead_form
    before_action :ensure_mql_form_allowed
    before_action :set_resolved_product
    after_action :allow_iframe_embedding

    # Anti-DoS: per-IP throttling backed by Rails.cache (Solid Cache in production).
    rate_limit to: 10, within: 1.minute, only: :create, name: "lead_form_create",
      with: -> { redirect_after_submission }
    rate_limit to: 60, within: 1.minute, only: %i[show success privacy], name: "lead_form_show"

    def show
      prepare_show_page
    rescue Liquid::FileSystemError
      head :not_found
    end

    def create
      if bot_suspected?
        redirect_after_submission
        return
      end

      unless gdpr_consent_given?
        flash.now[:alert] = t("public.lead_forms.gdpr_required")
        return render_show_or_not_found(status: :unprocessable_entity)
      end

      unless turnstile_passed?
        flash.now[:alert] = t("public.lead_forms.turnstile_failed")
        return render_show_or_not_found(status: :unprocessable_entity)
      end

      result = LeadFormSubmissionProcessor.call(
        lead_form: @lead_form,
        params: lead_params,
        request: request,
        product: @product,
        open_editions: @open_editions
      )
      redirect_after_submission(prefill: (redirect_prefill if result))
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence.presence || "No se pudo enviar el formulario."
      render_show_or_not_found(status: :unprocessable_entity)
    end

    def success
      @lead_form_page_html = template_renderer.render("public/lead_forms/success")
    rescue Liquid::FileSystemError
      head :not_found
    end

    def privacy
      @lead_form_page_html = template_renderer.render("public/lead_forms/privacy")
    rescue Liquid::FileSystemError
      head :not_found
    end

    private

    def ensure_feature_enabled
      return if CreamFeatures.enabled?(:lead_forms)

      head :not_found
    end

    def ensure_mql_form_allowed
      return unless @lead_form.mql_destination?
      return if CreamFeatures.enabled?(:mql_pool) && CreamFeatures.enabled?(:marketing_consent)

      head :not_found
    end

    def prepare_show_page
      capture_privacy_policy_version!
      @submission_key = SecureRandom.uuid if @lead_form.mql_destination?
      path = LeadFormTemplate.form_page_path_for(@lead_form.template_key)
      @lead_form_page_html = template_renderer.render(path)
    end

    def capture_privacy_policy_version!
      base_renderer = LeadFormTemplates::Renderer.new(
        workspace: @lead_form.workspace,
        lead_form: @lead_form,
        view_context: view_context,
        params: params,
        product: @product,
        open_editions: @open_editions || []
      )
      policy_html = base_renderer.render(PrivacyPolicyVersion::POLICY_PATH)
      statement_html = base_renderer.render("public/lead_forms/partials/consent_fields")
      @privacy_policy_version = Marketing::ConsentPolicySnapshot.capture(
        workspace: @lead_form.workspace,
        policy_html: policy_html,
        statement_html: statement_html
      )
      @privacy_policy_hash = @privacy_policy_version.content_hash
    end

    def render_show_or_not_found(status: :ok)
      prepare_show_page
      render :show, status: status
    rescue Liquid::FileSystemError
      head :not_found
    end

    def template_renderer
      @template_renderer ||= LeadFormTemplates::Renderer.new(
        workspace: @lead_form.workspace,
        lead_form: @lead_form,
        view_context: view_context,
        params: params,
        product: @product,
        open_editions: @open_editions || [],
        privacy_policy_hash: @privacy_policy_hash,
        submission_key: @submission_key
      )
    end

    def set_lead_form
      @lead_form = LeadForm.active.find_by!(slug: params[:slug])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def set_resolved_product
      product_id_param = params[:product_id].presence || params.dig(:lead, :product_id)
      @product = @lead_form.resolved_product(product_id_param:)
      @open_editions = @lead_form.open_editions_for(@product) if @product.present?
    end

    def lead_params
      raw = LeadForm.filter_submission_params(params.fetch(:lead, {}))
      raw.slice(*submission_schema.allowed_param_keys)
    end

    # Siempre lo que tecleó el visitante, nunca la ficha del CRM (ver
    # LeadForm::REDIRECT_PREFILL_KEYS).
    def redirect_prefill
      lead_params.slice(*LeadForm::REDIRECT_PREFILL_KEYS)
    end

    def submission_schema
      @submission_schema ||= LeadFormTemplates::SubmissionSchema.build(
        lead_form: @lead_form,
        product: @product,
        open_editions: @open_editions,
        params: LeadForm.filter_submission_params(params.fetch(:lead, {}))
      )
    end

    def gdpr_consent_given?
      lead_params["gdpr_consent"] == "1"
    end

    def bot_suspected?
      honeypot_triggered? || !LeadForm.submitted_after_min_time?(lead_params[LeadForm::TIMESTAMP_FIELD])
    end

    def honeypot_triggered?
      lead_params[LeadForm::HONEYPOT_FIELD].present?
    end

    def turnstile_passed?
      return true unless TurnstileVerifier.enabled?

      TurnstileVerifier.valid?(token: params["cf-turnstile-response"], ip: request.remote_ip)
    end

    # Sin prefill (bots, rate limit, descarte silencioso) la redirección va limpia:
    # los datos del envío solo viajan cuando el lead se ha creado de verdad.
    def redirect_after_submission(prefill: nil)
      notice = "Gracias. Hemos recibido tu solicitud."
      if (location = @lead_form.success_redirect_location(prefill: prefill))
        redirect_to location, notice: notice, allow_other_host: true
      else
        redirect_to public_lead_form_success_path(@lead_form.slug), notice: notice
      end
    end

    def allow_iframe_embedding
      response.headers.delete("X-Frame-Options")
      response.headers["Content-Security-Policy"] = "frame-ancestors *"
    end
  end
end
