module People
  class LeadSubmissionsController < ApplicationController
    include RequiresFeature
    requires_feature :lead_forms

    before_action :set_person
    before_action :set_submission

    def show
      authorize @person, :show?
      authorize @submission.lead_form, :show?
    end

    private

    def set_person
      @person = policy_scope(current_workspace.people).find(params[:person_id])
    end

    def set_submission
      @submission = @person.lead_submissions.find(params[:id])
    end
  end
end
