class CreateWorkbenchDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    create_table :events do |t|
      t.string :name, null: false
      t.date :event_date, null: false
      t.timestamps
    end
    add_index :events, [ :name, :event_date ], unique: true
    create_table :races do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.string :distance, null: false
      t.timestamps
    end
    add_index :races, [ :event_id, :name, :distance ], unique: true
    add_index :races, [ :id, :event_id ], unique: true
    create_table :athletes do |t|
      t.string :first_name, :last_name, :full_name, :identity_name
      t.string :id_number, :passport_number, :permanent_number
      t.date :date_of_birth
      t.string :gender, :email, :mobile_number
      t.string :weak_identity_key
      t.timestamps
    end
    add_index :athletes, :id_number, unique: true
    add_index :athletes, :passport_number, unique: true
    add_index :athletes, :weak_identity_key, unique: true
    add_index :athletes, [ :identity_name, :date_of_birth ]
    add_index :athletes, [ :identity_name, :date_of_birth ], unique: true,
      where: "id_number IS NULL AND passport_number IS NULL AND date_of_birth IS NOT NULL",
      name: "athletes_unique_weak_name_birth"
    create_table :clubs do |t|
      t.string :name, :normalized_name, null: false
      t.timestamps
    end
    add_index :clubs, :normalized_name, unique: true
    create_table :memberships do |t|
      t.references :athlete, null: false, foreign_key: true
      t.references :club, null: false, foreign_key: true
      t.timestamps
    end
    add_index :memberships, [ :athlete_id, :club_id ], unique: true
    create_table :import_batches do |t|
      t.references :user, :event, :race, null: false, foreign_key: true
      t.string :file_name, null: false
      t.string :status, default: "pending_mapping", null: false
      t.jsonb :preview_data, :mapping_config, default: {}, null: false
      t.integer :total_rows, :imported_rows, :failed_rows, :skipped_rows, default: 0, null: false
      t.string :claim_token, :job_id
      t.integer :attempts, default: 0, null: false
      t.datetime :queued_at, :started_at, :heartbeat_at, :completed_at
      t.text :fatal_error
      t.timestamps
    end
    add_index :import_batches, :status
    add_check_constraint :import_batches,
      "status IN ('pending_mapping', 'queued', 'processing', 'completed', 'completed_with_errors', 'failed')",
      name: "import_batches_valid_status"
    add_check_constraint :import_batches,
      "total_rows >= 0 AND imported_rows >= 0 AND failed_rows >= 0 AND skipped_rows >= 0",
      name: "import_batches_nonnegative_counts"
    # A model validation alone cannot protect crafted or concurrent context changes.
    reversible do |dir|
      dir.up { execute "ALTER TABLE import_batches ADD CONSTRAINT batch_race_event FOREIGN KEY (race_id, event_id) REFERENCES races(id, event_id)" }
      dir.down { execute "ALTER TABLE import_batches DROP CONSTRAINT batch_race_event" }
    end
    create_table :race_results do |t|
      t.references :athlete, :race, :import_batch, null: false, foreign_key: true
      t.string :race_number, :finish_status, :finish_time_display
      t.integer :finish_time_seconds, :overall_position, :category_position, :gender_position, :age_at_race
      t.string :category, :gender, :club
      t.timestamps
    end
    add_index :race_results, [ :race_id, :race_number ], unique: true, where: "race_number IS NOT NULL"
    add_index :race_results, [ :import_batch_id, :race_id, :athlete_id ], unique: true,
      where: "race_number IS NULL", name: "results_unique_without_race_number"
    create_table :import_rows do |t|
      t.references :import_batch, null: false, foreign_key: true
      t.references :athlete, :race_result, foreign_key: true
      t.string :source_sheet, null: false
      t.integer :source_row_number, null: false
      t.string :row_type, default: "unsupported", null: false
      t.string :status, default: "pending", null: false
      t.jsonb :raw_data, default: [], null: false
      t.jsonb :normalized_data, default: {}, null: false
      t.text :error_message
      t.timestamps
    end
    add_index :import_rows, [ :import_batch_id, :source_sheet, :source_row_number ], unique: true,
      name: "import_rows_unique_source"
    add_index :import_rows, [ :import_batch_id, :status ]
    add_check_constraint :import_rows, "status IN ('pending', 'imported', 'failed', 'skipped')", name: "import_rows_valid_status"
    create_table :versions do |t|
      t.string :item_type, :event, null: false
      t.bigint :item_id, null: false
      t.string :whodunnit
      t.jsonb :object, :object_changes
      t.datetime :created_at
    end
    add_index :versions, [ :item_type, :item_id ]
  end
end
