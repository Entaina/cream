module Api
  module V1
    class CompaniesController < BaseController
      def index
        companies = policy_scope(current_workspace.companies)
        companies = companies.search(params[:q]) if params[:q].present?
        render json: companies.map { |company| company_json(company) }
      end

      def show
        company = policy_scope(current_workspace.companies).find(params[:id])
        authorize company
        render json: company_json(company)
      end

      def create
        company = current_workspace.companies.new(company_params.merge(owner: current_user))
        authorize company

        if company.save
          render json: company_json(company), status: :created
        else
          render json: {errors: company.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def update
        company = policy_scope(current_workspace.companies).find(params[:id])
        authorize company

        if company.update(company_params)
          render json: company_json(company)
        else
          render json: {errors: company.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def destroy
        company = policy_scope(current_workspace.companies).find(params[:id])
        authorize company
        company.destroy
        head :no_content
      end

      private

      def company_params
        params.require(:company).permit(:name, :domain, :industry, :employee_range, :location, :annual_revenue)
      end

      def company_json(company)
        {
          id: company.id,
          name: company.name,
          domain: company.domain,
          industry: company.industry,
          created_at: company.created_at.iso8601,
          updated_at: company.updated_at.iso8601
        }
      end
    end
  end
end
