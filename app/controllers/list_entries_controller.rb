class ListEntriesController < ApplicationController
  before_action :set_list

  def create
    records = records_for_list(@list)
    record = policy_scope(records).find(params.require(:record_id))
    entry = @list.list_entries.new(record: record)
    authorize entry
    entry.save!
    redirect_to @list, notice: t("flashes.list_entries.added")
  end

  def destroy
    entry = @list.list_entries.find(params[:id])
    authorize entry
    entry.destroy
    redirect_to @list, notice: t("flashes.list_entries.removed"), status: :see_other
  end

  private

  def set_list
    @list = policy_scope(current_workspace.lists).find(params[:list_id])
    authorize @list, :show?
  end

  def records_for_list(list)
    case list.record_type
    when "Person" then current_workspace.people
    when "Company" then current_workspace.companies
    when "Deal" then policy_scope(current_workspace.deals)
    else raise ActiveRecord::RecordNotFound
    end
  end
end
