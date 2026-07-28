class CreatePipelinesAndProducts < ActiveRecord::Migration[8.1]
  # Default stages migrated from the old Deal::STAGES enum, with sales probabilities.
  DEFAULT_STAGES = [
    { key: "lead", name: "Lead", color: "chicago", probability: 10, won: false, closed: false },
    { key: "qualified", name: "Qualified", color: "hoki", probability: 25, won: false, closed: false },
    { key: "proposal", name: "Proposal", color: "copperfield", probability: 50, won: false, closed: false },
    { key: "negotiation", name: "Negotiation", color: "golden", probability: 75, won: false, closed: false },
    { key: "won", name: "Won", color: "green", probability: 100, won: true, closed: true },
    { key: "lost", name: "Lost", color: "red", probability: 0, won: false, closed: true }
  ].freeze

  def up
    create_table :pipelines do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :default_pipeline, null: false, default: false
      t.timestamps
    end

    create_table :pipeline_stages do |t|
      t.references :pipeline, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false, default: "chicago"
      t.integer :probability, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.boolean :won, null: false, default: false
      t.boolean :closed, null: false, default: false
      t.timestamps
    end
    add_index :pipeline_stages, [ :pipeline_id, :position ]

    create_table :products do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 14, scale: 2, null: false, default: 0
      t.timestamps
    end
    add_index :products, [ :workspace_id, :name ]

    create_table :deal_products do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_price, precision: 14, scale: 2, null: false, default: 0
      t.timestamps
    end

    add_reference :deals, :pipeline, foreign_key: true
    add_reference :deals, :pipeline_stage, foreign_key: true

    # Backfill: one "Ventas" pipeline per workspace with the default stages,
    # then point each deal at the stage matching its old `stage` string.
    execute(<<~SQL)
      INSERT INTO pipelines (workspace_id, name, position, default_pipeline, created_at, updated_at)
      SELECT id, 'Ventas', 0, true, NOW(), NOW() FROM workspaces
    SQL

    DEFAULT_STAGES.each_with_index do |stage, index|
      execute(<<~SQL)
        INSERT INTO pipeline_stages
          (pipeline_id, workspace_id, name, color, probability, position, won, closed, created_at, updated_at)
        SELECT p.id, p.workspace_id,
               #{quote(stage[:name])}, #{quote(stage[:color])}, #{stage[:probability]},
               #{index}, #{quote(stage[:won])}, #{quote(stage[:closed])}, NOW(), NOW()
        FROM pipelines p
      SQL
    end

    DEFAULT_STAGES.each do |stage|
      execute(<<~SQL)
        UPDATE deals d
        SET pipeline_id = ps.pipeline_id, pipeline_stage_id = ps.id
        FROM pipeline_stages ps
        WHERE ps.workspace_id = d.workspace_id
          AND ps.name = #{quote(stage[:name])}
          AND d.stage = #{quote(stage[:key])}
      SQL
    end

    change_column_null :deals, :pipeline_id, false
    change_column_null :deals, :pipeline_stage_id, false

    remove_index :deals, column: [ :workspace_id, :stage, :position ], if_exists: true
    add_index :deals, [ :workspace_id, :pipeline_stage_id, :position ]
    remove_column :deals, :stage
  end

  def down
    add_column :deals, :stage, :string, null: false, default: "lead"
    DEFAULT_STAGES.each do |stage|
      execute(<<~SQL)
        UPDATE deals d
        SET stage = #{quote(stage[:key])}
        FROM pipeline_stages ps
        WHERE d.pipeline_stage_id = ps.id AND ps.name = #{quote(stage[:name])}
      SQL
    end
    add_index :deals, [ :workspace_id, :stage, :position ]

    remove_reference :deals, :pipeline_stage, foreign_key: true
    remove_reference :deals, :pipeline, foreign_key: true
    drop_table :deal_products
    drop_table :products
    drop_table :pipeline_stages
    drop_table :pipelines
  end
end
