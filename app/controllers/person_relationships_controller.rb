class PersonRelationshipsController < ApplicationController
  before_action :set_person

  def create
    to_person = current_workspace.people.find(relationship_params[:to_person_id])
    @relationship = @person.outgoing_relationships.build(
      to_person: to_person,
      relationship_type: relationship_params[:relationship_type]
    )
    authorize @relationship

    if @relationship.save
      redirect_to person_path(@person), notice: t("flashes.person_relationships.added")
    else
      redirect_to person_path(@person), alert: @relationship.errors.full_messages.to_sentence
    end
  end

  def destroy
    @relationship = policy_scope(PersonRelationship).find(params[:id])
    authorize @relationship
    raise ActiveRecord::RecordNotFound unless @relationship.involves?(@person)

    @relationship.destroy
    redirect_to person_path(@person), notice: t("flashes.person_relationships.removed"), status: :see_other
  end

  private

  def set_person
    @person = policy_scope(current_workspace.people).find(params[:person_id])
    authorize @person, :show?
  end

  def relationship_params
    params.require(:person_relationship).permit(:to_person_id, :relationship_type)
  end
end
