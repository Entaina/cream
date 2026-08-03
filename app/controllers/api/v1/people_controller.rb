module Api
  module V1
    class PeopleController < BaseController
      def index
        people = policy_scope(current_workspace.people).includes(:company, :person_emails)
        people = people.search(params[:q]) if params[:q].present?
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
          render json: { errors: person.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        person = policy_scope(current_workspace.people).find(params[:id])
        authorize person

        if person.update(person_params)
          render json: person_json(person)
        else
          render json: { errors: person.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        person = policy_scope(current_workspace.people).find(params[:id])
        authorize person
        person.destroy
        head :no_content
      end

      private

      def person_params
        params.require(:person).permit(:first_name, :last_name, :email, :phone, :job_title, :location, :company_id,
          person_emails_attributes: [ :id, :address, :primary, :_destroy ])
      end

      def person_json(person)
        {
          id: person.id,
          first_name: person.first_name,
          last_name: person.last_name,
          email: person.email,
          emails: person.person_emails.ordered.map { |record| { address: record.address, primary: record.primary? } },
          company_id: person.company_id,
          company: person.company&.name,
          created_at: person.created_at.iso8601,
          updated_at: person.updated_at.iso8601
        }
      end
    end
  end
end
