# frozen_string_literal: true

class AddSearchTokensToLlmemory < ActiveRecord::Migration[8.0]
  def change
    add_column :llmemory_items, :search_tokens, :text
    add_column :llmemory_resources, :search_tokens, :text
    add_column :llmemory_episodes, :search_tokens, :text
    add_column :llmemory_skills, :search_tokens, :text
    add_column :llmemory_skills, :name_det, :text
  end
end
