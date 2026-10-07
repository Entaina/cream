module Api
  module V1
    class PeopleController < BaseController
      def index
        people = policy_scope(current_workspace.people).includes(:company, :person_emails)
        people = people.search(params[:q]) if params[:q].present?
        people = people.with_email(params[:email]) if params[:email].present?
        render json: people.map { |person| person_json(person) }
      end

      def show
        person = policy_scope(current_workspace.people).find(params[:id])
        authorize person
        render json: person_json(person)
      end

      def create
        person = current_workspace.people.new(person_params.merge(owner: current_user))
        authorize person

        if person.save
          render json: person_json(person), status: :created
        else
          render json: {errors: person.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def update
        person = policy_scope(current_workspace.people).find(params[:id])
        authorize person

        if person.update(person_params)
          render json: person_json(person)
        else
          render json: {errors: person.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def destroy
        person = policy_scope(current_workspace.people).find(params[:id])
        authorize person
        person.destroy
        head :no_content
      end

      def marketing
        person = policy_scope(current_workspace.people).find(params[:id])
        authorize person, :show?
        render json: ::Marketing::ApiPresenter.person_marketing_json(person, current_workspace)
      end

      def subscription
        return feature_unavailable!(:marketing_consent) unless CreamFeatures.enabled?(:marketing_consent)

        person = policy_scope(current_workspace.people).find(params[:id])
        authorize person, :update?
        type = current_workspace.subscription_types.find(subscription_params[:subscription_type_id])

        case subscription_params[:action]
        when "subscribe"
          evidence = ::Marketing::ConsentEvidence.parse(subscription_params)
          subscription = EmailSubscription.find_by(person: person, subscription_type: type)
          # An active subscription keeps the evidence it was originally obtained with.
          unless subscription&.subscribed?
            subscription = ::Marketing::ConsentService.subscribe!(
              person: person,
              subscription_type: type,
              source: "api",
              legal_basis: "consent",
              metadata: evidence.metadata(user: current_user)
            )
          end
        when "unsubscribe"
          ::Marketing::ConsentService.unsubscribe!(
            person: person,
            subscription_type: type,
            source: "api"
          )
          subscription = EmailSubscription.find_by(person: person, subscription_type: type)
        else
          return render json: {error: "action must be subscribe or unsubscribe"}, status: :unprocessable_entity
        end

        render json: {
          action: subscription_params[:action],
          subscription: subscription && ::Marketing::ApiPresenter.subscription_json(subscription)
        }
      rescue ::Marketing::ConsentEvidence::Error => e
        render json: {errors: [e.message]}, status: :unprocessable_entity
      end

      private

      def feature_unavailable!(flag)
        render json: {error: CreamFeatures.unavailable_message(flag)}, status: :not_found
      end

      def subscription_params
        params.require(:subscription).permit(
          :subscription_type_id, :action, :consent_text, :consent_source, :consent_obtained_at, :consent_ip
        )
      end

      def person_params
        params.require(:person).permit(:first_name, :last_name, :email, :phone, :job_title, :location, :internal_notes, :company_id,
          person_emails_attributes: [:id, :address, :primary, :_destroy])
      end

      def person_json(person)
        {
          id: person.id,
          first_name: person.first_name,
          last_name: person.last_name,
          email: person.email,
          emails: person.person_emails.ordered.map { |record| {address: record.address, primary: record.primary?} },
          internal_notes: person.internal_notes,
          company_id: person.company_id,
          company: person.company&.name,
          created_at: person.created_at.iso8601,
          updated_at: person.updated_at.iso8601
        }
      end
    end
  end
end
