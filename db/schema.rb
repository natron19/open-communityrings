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

ActiveRecord::Schema[8.1].define(version: 2026_05_06_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "ai_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "max_output_tokens", default: 2000, null: false
    t.string "model", default: "gemini-2.0-flash", null: false
    t.string "name", null: false
    t.text "notes"
    t.text "system_prompt", null: false
    t.decimal "temperature", precision: 3, scale: 1, default: "0.7"
    t.datetime "updated_at", null: false
    t.text "user_prompt_template", null: false
    t.index ["name"], name: "index_ai_templates_on_name", unique: true
  end

  create_table "llm_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ai_template_id"
    t.decimal "cost_estimate_cents", precision: 10, scale: 4
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.integer "prompt_token_count"
    t.integer "response_token_count"
    t.string "status", default: "pending", null: false
    t.string "template_name"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["ai_template_id"], name: "index_llm_requests_on_ai_template_id"
    t.index ["created_at"], name: "index_llm_requests_on_created_at"
    t.index ["status"], name: "index_llm_requests_on_status"
    t.index ["user_id"], name: "index_llm_requests_on_user_id"
  end

  create_table "overlaps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "cross_ring_idea", null: false
    t.uuid "ring_a_id", null: false
    t.uuid "ring_b_id", null: false
    t.uuid "ring_map_id", null: false
    t.text "shared_element", null: false
    t.datetime "updated_at", null: false
    t.index ["ring_a_id"], name: "index_overlaps_on_ring_a_id"
    t.index ["ring_b_id"], name: "index_overlaps_on_ring_b_id"
    t.index ["ring_map_id", "ring_a_id", "ring_b_id"], name: "index_overlaps_on_ring_map_id_and_ring_a_id_and_ring_b_id", unique: true
    t.index ["ring_map_id"], name: "index_overlaps_on_ring_map_id"
  end

  create_table "password_resets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.uuid "user_id", null: false
    t.index ["token"], name: "index_password_resets_on_token", unique: true
    t.index ["user_id"], name: "index_password_resets_on_user_id"
  end

  create_table "profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "family_situation"
    t.text "interests"
    t.text "known_rings"
    t.text "life_context", null: false
    t.text "neighborhood"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.text "values"
    t.integer "weekly_hours", null: false
    t.text "work_occupation"
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "ring_maps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "gemini_raw"
    t.text "gemini_raw_overlaps"
    t.datetime "generated_at", null: false
    t.datetime "overlaps_regenerated_at"
    t.uuid "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["generated_at"], name: "index_ring_maps_on_generated_at"
    t.index ["profile_id"], name: "index_ring_maps_on_profile_id"
  end

  create_table "rings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.boolean "is_priority", default: false, null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.text "rationale", null: false
    t.uuid "ring_map_id", null: false
    t.string "ring_type", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["ring_map_id", "position"], name: "index_rings_on_ring_map_id_and_position", unique: true
    t.index ["ring_map_id"], name: "index_rings_on_ring_map_id"
  end

  create_table "starter_initiatives", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "activities", null: false
    t.datetime "created_at", null: false
    t.text "expected_outcomes", null: false
    t.text "goal", null: false
    t.text "next_step", null: false
    t.uuid "ring_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ring_id"], name: "index_starter_initiatives_on_ring_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "llm_requests", "ai_templates"
  add_foreign_key "llm_requests", "users"
  add_foreign_key "overlaps", "ring_maps"
  add_foreign_key "overlaps", "rings", column: "ring_a_id"
  add_foreign_key "overlaps", "rings", column: "ring_b_id"
  add_foreign_key "password_resets", "users"
  add_foreign_key "profiles", "users"
  add_foreign_key "ring_maps", "profiles"
  add_foreign_key "rings", "ring_maps"
  add_foreign_key "starter_initiatives", "rings"
end
