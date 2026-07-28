# frozen_string_literal: true

class CreateLlmemoryTables < ActiveRecord::Migration[8.0]
  def change
    create_table :llmemory_resources, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :user_id, null: false
      t.text :text, null: false
      t.timestamps
    end
    add_index :llmemory_resources, :user_id

    create_table :llmemory_items, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :user_id, null: false
      t.string :category, null: false
      t.text :content, null: false
      t.string :source_resource_id
      t.float :importance, default: 0.7
      t.jsonb :provenance
      t.timestamps
    end
    add_index :llmemory_items, :user_id

    create_table :llmemory_categories do |t|
      t.string :user_id, null: false
      t.string :category_name, null: false
      t.text :content, null: false
      t.datetime :updated_at, null: false
    end
    add_index :llmemory_categories, [:user_id, :category_name], unique: true

    # Episodic long-term memory (trajectories) — JSONB document per episode
    create_table :llmemory_episodes, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :user_id, null: false
      t.jsonb :data, null: false, default: {}
      t.text :search_text
      t.datetime :archived_at
      t.timestamps
    end
    add_index :llmemory_episodes, :user_id

    # Procedural long-term memory (skill library) — JSONB document per skill
    create_table :llmemory_skills, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :user_id, null: false
      t.jsonb :data, null: false, default: {}
      t.text :search_text
      t.datetime :archived_at
      t.timestamps
    end
    add_index :llmemory_skills, :user_id

    create_table :llmemory_checkpoints do |t|
      t.string :user_id, null: false
      t.string :session_id, null: false
      t.jsonb :state, null: false, default: {}
      t.timestamps
    end
    add_index :llmemory_checkpoints, [:user_id, :session_id], unique: true

    # Graph-based long-term memory (nodes = entities)
    create_table :llmemory_nodes do |t|
      t.string :user_id, null: false
      t.string :entity_type, null: false
      t.string :name, null: false
      t.jsonb :properties, default: {}
      t.timestamps
    end
    add_index :llmemory_nodes, [:user_id, :entity_type, :name], unique: true

    # Graph-based long-term memory (edges = SPO relations)
    create_table :llmemory_edges do |t|
      t.string :user_id, null: false
      t.references :subject, null: false, foreign_key: { to_table: :llmemory_nodes }
      t.string :predicate, null: false
      t.references :object, null: false, foreign_key: { to_table: :llmemory_nodes }
      t.jsonb :properties, default: {}
      t.datetime :archived_at
      t.timestamps
    end
    add_index :llmemory_edges, [:user_id, :subject_id, :predicate]

    # Vector store for hybrid retrieval (requires pgvector extension)
    enable_extension "vector"
    create_table :llmemory_embeddings do |t|
      t.string :user_id, null: false
      t.string :source_type, null: false
      t.string :source_id, null: false
      t.column :embedding, "vector(1536)"
      t.text :text_content
      t.timestamps
    end
    add_index :llmemory_embeddings, [:user_id, :source_type, :source_id], unique: true
  end
end
