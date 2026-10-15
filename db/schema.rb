# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_15_104416) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "athletes", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "full_name"
    t.string "identity_name"
    t.string "id_number"
    t.string "passport_number"
    t.string "permanent_number"
    t.date "date_of_birth"
    t.string "gender"
    t.string "email"
    t.string "mobile_number"
    t.string "weak_identity_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id_number"], name: "index_athletes_on_id_number", unique: true
    t.index ["identity_name", "date_of_birth"], name: "athletes_unique_weak_name_birth", unique: true, where: "((id_number IS NULL) AND (passport_number IS NULL) AND (date_of_birth IS NOT NULL))"
    t.index ["identity_name", "date_of_birth"], name: "index_athletes_on_identity_name_and_date_of_birth"
    t.index ["passport_number"], name: "index_athletes_on_passport_number", unique: true
    t.index ["weak_identity_key"], name: "index_athletes_on_weak_identity_key", unique: true
  end

  create_table "clubs", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_name"], name: "index_clubs_on_normalized_name", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "name", null: false
    t.date "event_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "event_date"], name: "index_events_on_name_and_event_date", unique: true
  end

  create_table "import_batches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.bigint "race_id", null: false
    t.string "file_name", null: false
    t.string "status", default: "pending_mapping", null: false
    t.jsonb "preview_data", default: {}, null: false
    t.jsonb "mapping_config", default: {}, null: false
    t.integer "total_rows", default: 0, null: false
    t.integer "imported_rows", default: 0, null: false
    t.integer "failed_rows", default: 0, null: false
    t.integer "skipped_rows", default: 0, null: false
    t.string "claim_token"
    t.string "job_id"
    t.integer "attempts", default: 0, null: false
    t.datetime "queued_at"
    t.datetime "started_at"
    t.datetime "heartbeat_at"
    t.datetime "completed_at"
    t.text "fatal_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_import_batches_on_event_id"
    t.index ["race_id"], name: "index_import_batches_on_race_id"
    t.index ["status"], name: "index_import_batches_on_status"
    t.index ["user_id"], name: "index_import_batches_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['pending_mapping'::character varying, 'queued'::character varying, 'processing'::character varying, 'completed'::character varying, 'completed_with_errors'::character varying, 'failed'::character varying]::text[])", name: "import_batches_valid_status"
    t.check_constraint "total_rows >= 0 AND imported_rows >= 0 AND failed_rows >= 0 AND skipped_rows >= 0", name: "import_batches_nonnegative_counts"
  end

  create_table "import_rows", force: :cascade do |t|
    t.bigint "import_batch_id", null: false
    t.bigint "athlete_id"
    t.bigint "race_result_id"
    t.string "source_sheet", null: false
    t.integer "source_row_number", null: false
    t.string "row_type", default: "unsupported", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "raw_data", default: [], null: false
    t.jsonb "normalized_data", default: {}, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["athlete_id"], name: "index_import_rows_on_athlete_id"
    t.index ["import_batch_id", "source_sheet", "source_row_number"], name: "import_rows_unique_source", unique: true
    t.index ["import_batch_id", "status"], name: "index_import_rows_on_import_batch_id_and_status"
    t.index ["import_batch_id"], name: "index_import_rows_on_import_batch_id"
    t.index ["race_result_id"], name: "index_import_rows_on_race_result_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'imported'::character varying, 'failed'::character varying, 'skipped'::character varying]::text[])", name: "import_rows_valid_status"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "athlete_id", null: false
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["athlete_id", "club_id"], name: "index_memberships_on_athlete_id_and_club_id", unique: true
    t.index ["athlete_id"], name: "index_memberships_on_athlete_id"
    t.index ["club_id"], name: "index_memberships_on_club_id"
  end

  create_table "race_results", force: :cascade do |t|
    t.bigint "athlete_id", null: false
    t.bigint "race_id", null: false
    t.bigint "import_batch_id", null: false
    t.string "race_number"
    t.string "finish_status"
    t.string "finish_time_display"
    t.integer "finish_time_seconds"
    t.integer "overall_position"
    t.integer "category_position"
    t.integer "gender_position"
    t.integer "age_at_race"
    t.string "category"
    t.string "gender"
    t.string "club"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["athlete_id"], name: "index_race_results_on_athlete_id"
    t.index ["import_batch_id", "race_id", "athlete_id"], name: "results_unique_without_race_number", unique: true, where: "(race_number IS NULL)"
    t.index ["import_batch_id"], name: "index_race_results_on_import_batch_id"
    t.index ["race_id", "race_number"], name: "index_race_results_on_race_id_and_race_number", unique: true, where: "(race_number IS NOT NULL)"
    t.index ["race_id"], name: "index_race_results_on_race_id"
  end

  create_table "races", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.string "distance", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "name", "distance"], name: "index_races_on_event_id_and_name_and_distance", unique: true
    t.index ["event_id"], name: "index_races_on_event_id"
    t.index ["id", "event_id"], name: "index_races_on_id_and_event_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "whodunnit"
    t.jsonb "object"
    t.jsonb "object_changes"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "import_batches", "events"
  add_foreign_key "import_batches", "races"
  add_foreign_key "import_batches", "races", column: ["race_id", "event_id"], primary_key: ["id", "event_id"], name: "batch_race_event"
  add_foreign_key "import_batches", "users"
  add_foreign_key "import_rows", "athletes"
  add_foreign_key "import_rows", "import_batches"
  add_foreign_key "import_rows", "race_results"
  add_foreign_key "memberships", "athletes"
  add_foreign_key "memberships", "clubs"
  add_foreign_key "race_results", "athletes"
  add_foreign_key "race_results", "import_batches"
  add_foreign_key "race_results", "races"
  add_foreign_key "races", "events"
  add_foreign_key "sessions", "users"
end
