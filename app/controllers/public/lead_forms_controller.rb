module Public
  class LeadFormsController < ApplicationController
    layout "public_lead_form"

    allow_unauthenticated_access only: %i[show create success]
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :ensure_feature_enabled
    before_action :set_lead_form
    after_action :allow_iframe_embedding

    # Anti-DoS: per-IP throttling backed by Rails.cache (Solid Cache in production).
    rate_limit to: 10, within: 1.minute, only: :create, name: "lead_form_create",
      with: -> { redirect_after_submission }
    rate_limit to: 60, within: 1.minute, only: %i[show success], name: "lead_form_show"

    def show
    end

    def create
      if bot_suspected?
        redirect_after_submission
        return
      end

      unless gdpr_consent_given?
        flash.now[:alert] = "Debes aceptar la política de privacidad para enviar el formulario."
        render :show, status: :unprocessable_entity
        return
      end

      unless turnstile_passed?
        flash.now[:alert] = "No hemos podido verificar que eres una persona. Vuelve a intentarlo."
        render :show, status: :unprocessable_entity
        return
      end

      LeadFormSubmissionProcessor.call(
        lead_form: @lead_form,
        params: lead_params,
        request: request
      )
      redirect_after_submission
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence.presence || "No se pudo enviar el formulario."
      render :show, status: :unprocessable_entity
    end

    def success
    end

    private

    def ensure_feature_enabled
      return if CreamFeatures.enabled?(:lead_forms)

      head :not_found
    end

    def set_lead_form
      @lead_form = LeadForm.active.find_by!(slug: params[:slug])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def lead_params
      params.fetch(:lead, {}).permit(
        :email, :first_name, :last_name, :phone, :how_heard, :help_type, :message,
        :company_name, :company_cif, :employee_range, :qualifying_answer, :job_title, :audience, :tech_profile, :ia_work_task, :ia_build_automation,
        :organization_ia_stage,
        :newsletter_opt_in, :gdpr_consent,
        :lead_form_slug, :lead_form_name,
        :source_page, :referrer, :utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content,
        LeadForm::HONEYPOT_FIELD, LeadForm::TIMESTAMP_FIELD,
        *@lead_form.hidden_field_keys
      ).to_h
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

    def redirect_after_submission
      notice = "Gracias. Hemos recibido tu solicitud."
      if (location = @lead_form.success_redirect_location)
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
