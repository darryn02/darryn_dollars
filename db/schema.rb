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

ActiveRecord::Schema[7.0].define(version: 2022_11_15_052306) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "nickname"
    t.decimal "credit_limit", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_accounts_on_name"
    t.index ["nickname"], name: "index_accounts_on_nickname"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "competitors", id: :serial, force: :cascade do |t|
    t.integer "sport", null: false
    t.citext "abbreviation"
    t.citext "nicknames", default: [], null: false, array: true
    t.citext "region"
    t.citext "name", null: false
    t.citext "full_name", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["abbreviation"], name: "index_competitors_on_abbreviation"
    t.index ["name"], name: "index_competitors_on_name"
    t.index ["nicknames"], name: "index_competitors_on_nicknames", using: :gin
    t.index ["region"], name: "index_competitors_on_region"
    t.index ["sport"], name: "index_competitors_on_sport"
  end

  create_table "contestants", id: :serial, force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "competitor_id", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "scores", default: [], null: false, array: true
    t.index ["competitor_id"], name: "index_contestants_on_competitor_id"
    t.index ["game_id"], name: "index_contestants_on_game_id"
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at", precision: nil
    t.datetime "locked_at", precision: nil
    t.datetime "failed_at", precision: nil
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "games", id: :serial, force: :cascade do |t|
    t.datetime "starts_at", precision: nil
    t.integer "sport", null: false
    t.integer "cached_competitor_ids", default: [], null: false, array: true
    t.string "md5_digest", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["md5_digest"], name: "index_games_on_md5_digest"
  end

  create_table "lines", id: :serial, force: :cascade do |t|
    t.integer "contestant_id"
    t.integer "game_id", null: false
    t.string "description"
    t.integer "kind", null: false
    t.integer "scope", null: false
    t.float "value", null: false
    t.integer "odds", default: -110, null: false
    t.boolean "hidden", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "result", default: 0, null: false
    t.index ["contestant_id"], name: "index_lines_on_contestant_id"
    t.index ["game_id"], name: "index_lines_on_game_id"
    t.index ["kind"], name: "index_lines_on_kind"
    t.index ["scope"], name: "index_lines_on_scope"
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount", null: false
    t.datetime "submitted_at", null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_payments_on_account_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.boolean "admin"
    t.string "name", null: false
    t.string "email", null: false
    t.string "mobile", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "wagers", id: :serial, force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "line_id", null: false
    t.datetime "placed_at", precision: nil
    t.decimal "amount"
    t.float "vig"
    t.integer "status", default: 0, null: false
    t.decimal "net"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["account_id"], name: "index_wagers_on_account_id"
    t.index ["line_id"], name: "index_wagers_on_line_id"
  end

  add_foreign_key "accounts", "users", on_delete: :cascade
  add_foreign_key "contestants", "competitors"
  add_foreign_key "contestants", "games"
  add_foreign_key "lines", "contestants", on_delete: :nullify
  add_foreign_key "lines", "games", on_delete: :cascade
  add_foreign_key "payments", "accounts", on_delete: :cascade
  add_foreign_key "wagers", "accounts", on_delete: :cascade
  add_foreign_key "wagers", "lines"
end
