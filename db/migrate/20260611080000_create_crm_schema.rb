class CreateCrmSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.timestamps
    end

    create_table :memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
      t.index [ :workspace_id, :user_id ], unique: true
    end

    create_table :companies do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :domain
      t.text :description
      t.string :industry
      t.string :employee_range
      t.string :location
      t.string :linkedin_url
      t.string :twitter_url
      t.bigint :annual_revenue
      t.references :owner, foreign_key: { to_table: :users }
      t.timestamps
      t.index [ :workspace_id, :name ]
      t.index [ :workspace_id, :domain ]
    end

    create_table :people do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :first_name, null: false, default: ""
      t.string :last_name, null: false, default: ""
      t.string :email
      t.string :phone
      t.string :job_title
      t.string :location
      t.string :linkedin_url
      t.string :twitter_url
      t.text :description
      t.references :company, foreign_key: true
      t.references :owner, foreign_key: { to_table: :users }
      t.timestamps
      t.index [ :workspace_id, :email ]
      t.index [ :workspace_id, :last_name, :first_name ]
    end

    create_table :deals do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :stage, null: false, default: "lead"
      t.decimal :value, precision: 14, scale: 2, default: 0
      t.string :currency, null: false, default: "EUR"
      t.integer :probability, default: 0
      t.date :expected_close_date
      t.integer :position, null: false, default: 0
      t.references :company, foreign_key: true
      t.references :person, foreign_key: true
      t.references :owner, foreign_key: { to_table: :users }
      t.timestamps
      t.index [ :workspace_id, :stage, :position ]
    end

    create_table :notes do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :notable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :body
      t.timestamps
    end

    create_table :tasks do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :taskable, polymorphic: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.date :due_on
      t.datetime :completed_at
      t.timestamps
      t.index [ :workspace_id, :completed_at ]
    end

    create_table :lists do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :record_type, null: false # Person | Company | Deal
      t.string :color, null: false, default: "blue"
      t.timestamps
    end

    create_table :list_entries do |t|
      t.references :list, null: false, foreign_key: true
      t.references :record, polymorphic: true, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [ :list_id, :record_type, :record_id ], unique: true
    end

    create_table :activities do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :subject, polymorphic: true, null: false
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
      t.index [ :workspace_id, :created_at ]
    end
  end
end
