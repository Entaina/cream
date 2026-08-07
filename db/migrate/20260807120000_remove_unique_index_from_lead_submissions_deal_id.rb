class RemoveUniqueIndexFromLeadSubmissionsDealId < ActiveRecord::Migration[8.0]
  def change
    remove_index :lead_submissions, :deal_id
    add_index :lead_submissions, :deal_id
  end
end
