# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2017_08_23_033013) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "nickname"
    t.decimal "credit_limit", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_accounts_on_name"
    t.index ["nickname"], name: "index_accounts_on_nickname"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "betting_slips", id: :serial, force: :cascade do |t|
    t.integer "account_id", null: false
    t.boolean "confirmed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_betting_slips_on_account_id"
  end

  create_table "competitors", id: :serial, force: :cascade do |t|
    t.integer "sport", null: false
    t.citext "abbreviation"
    t.citext "nicknames", default: [], null: false, array: true
    t.citext "region"
    t.citext "name", null: false
    t.citext "full_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_competitors_on_lower_name"
    t.index "lower((region)::text)", name: "index_competitors_on_lower_region"
    t.index ["abbreviation"], name: "index_competitors_on_abbreviation"
    t.index ["nicknames"], name: "index_competitors_on_nicknames", using: :gin
    t.index ["sport"], name: "index_competitors_on_sport"
  end

  create_table "contestants", id: :serial, force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "competitor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competitor_id"], name: "index_contestants_on_competitor_id"
    t.index ["game_id"], name: "index_contestants_on_game_id"
  end

  create_table "contests", id: :serial, force: :cascade do |t|
    t.integer "contestant_id", null: false
    t.integer "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contestant_id"], name: "index_contests_on_contestant_id"
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "games", id: :serial, force: :cascade do |t|
    t.datetime "starts_at"
    t.integer "sport", null: false
    t.text "cached_competitor_ids", default: [], null: false, array: true
    t.string "md5_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["md5_digest"], name: "index_games_on_md5_digest"
  end

  create_table "lines", id: :serial, force: :cascade do |t|
    t.integer "contest_id", null: false
    t.string "type", null: false
    t.float "value", null: false
    t.integer "odds", default: -110, null: false
    t.boolean "hidden", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contest_id"], name: "index_lines_on_contest_id"
    t.index ["type"], name: "index_lines_on_type"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.boolean "admin"
    t.string "name", null: false
    t.string "email", null: false
    t.string "mobile", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wagers", id: :serial, force: :cascade do |t|
    t.integer "betting_slip_id", null: false
    t.integer "line_id", null: false
    t.datetime "placed_at"
    t.decimal "amount_wagered"
    t.float "vig"
    t.integer "result"
    t.decimal "net"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["betting_slip_id"], name: "index_wagers_on_betting_slip_id"
    t.index ["line_id"], name: "index_wagers_on_line_id"
  end

  add_foreign_key "accounts", "users", on_delete: :cascade
  add_foreign_key "betting_slips", "accounts", on_delete: :cascade
  add_foreign_key "contestants", "competitors"
  add_foreign_key "contestants", "games"
  add_foreign_key "contests", "contestants"
  add_foreign_key "lines", "contests"
  add_foreign_key "wagers", "betting_slips"
  add_foreign_key "wagers", "lines"
end
