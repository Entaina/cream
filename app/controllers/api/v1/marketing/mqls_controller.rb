module Api
  module V1
    module Marketing
      class MqlsController < BaseController
        requires_feature :mql_pool

        def index
          authorize :mql, :index?

          filters = ::Marketing::ApiPresenter.mql_filters_from_params(params)
          base = ::Marketing::MqlEligibility.scope(
            workspace: current_workspace,
            subscription_type_id: filters["subscription_type_id"]
          )
          people = ::Marketing::FilterResolver.new(
            workspace: current_workspace,
            record_type: "Person",
            filters: filters,
            deal_scope: policy_scope(current_workspace.deals)
          ).resolve(
            base.includes(:company, :product_interests, email_subscriptions: :subscription_type)
          )

          people = people.order(lead_score: :desc, updated_at: :desc).limit(list_limit)
          render json: people.map { |person| ::Marketing::ApiPresenter.mql_json(person) }
        end

        # Registers a person as an MQL (find-or-create by email) with consent, notes and attachments.
        def create
          return feature_unavailable!(:marketing_consent) unless CreamFeatures.enabled?(:marketing_consent)

          authorize :mql, :create?
          result = ::Marketing::MqlCreator.call(
            workspace: current_workspace,
            user: current_user,
            source: "api",
            authorizer: ->(record, query, **options) { authorize(record, query, **options) },
            attributes: mql_params.to_h,
            subscriptions: nested_subscriptions,
            product_id: mql_params[:product_id],
            interest_description: mql_params[:interest_description],
            notes: nested_notes,
            attachments: ::Api::DealEmailCreator.parse_attachments(params[:attachments]),
            email_data: nested_email_params
          )
          render json: ::Marketing::ApiPresenter.mql_creation_json(result), status: result.created ? :created : :ok
        rescue ::Marketing::MqlCreator::Error, ::Api::RecordAttachmentBuilder::InvalidAttachment,
          ::Api::DealEmailCreator::InvalidAttachment => e
          render json: {errors: [e.message]}, status: :unprocessable_entity
        rescue ActiveRecord::RecordInvalid => e
          render json: {errors: e.record.errors.full_messages}, status: :unprocessable_entity
        end

        private

        def feature_unavailable!(flag)
          render json: {error: CreamFeatures.unavailable_message(flag)}, status: :not_found
        end

        def mql_params
          @mql_params ||= params.require(:mql).permit(
            :first_name, :last_name, :email, :phone, :job_title, :location, :company_id, :company_name,
            :internal_notes, :product_id, :interest_description
          )
        end

        def nested_subscriptions
          Array(params[:subscriptions]).filter_map do |entry|
            next unless entry.is_a?(ActionController::Parameters) || entry.is_a?(Hash)

            entry = ActionController::Parameters.new(entry) unless entry.is_a?(ActionController::Parameters)
            entry.permit(:subscription_type_id, :consent_text, :consent_source, :consent_obtained_at, :consent_ip).to_h
          end
        end

        def nested_notes
          Array(params[:notes]).filter_map do |entry|
            next unless entry.is_a?(ActionController::Parameters) || entry.is_a?(Hash)

            entry = ActionController::Parameters.new(entry) unless entry.is_a?(ActionController::Parameters)
            entry.permit(:title, :body).to_h.presence
          end
        end

        def nested_email_requested?
          params.key?(:email) && params[:email].present?
        end

        def nested_email_params
          return unless nested_email_requested?

          entry = params[:email]
          entry = ActionController::Parameters.new(entry) unless entry.is_a?(ActionController::Parameters)
          {
            attrs: entry.permit(:to_address, :subject, :body).to_h,
            attachments: ::Api::DealEmailCreator.parse_attachments(entry[:attachments])
          }
        end
      end
    end
  end
end
