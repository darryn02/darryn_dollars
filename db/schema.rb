# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170823033013) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "betting_slips", force: :cascade do |t|
    t.integer  "user_id"
    t.boolean  "confirmed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_betting_slips_on_user_id", using: :btree
  end

  create_table "competetors", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contestants", force: :cascade do |t|
    t.integer  "contest_id",    null: false
    t.integer  "competetor_id", null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.index ["competetor_id"], name: "index_contestants_on_competetor_id", using: :btree
    t.index ["contest_id"], name: "index_contestants_on_contest_id", using: :btree
  end

  create_table "contests", force: :cascade do |t|
    t.string   "name"
    t.boolean  "primary",    default: false, null: false
    t.integer  "game_id",                    null: false
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.index ["game_id"], name: "index_contests_on_game_id", using: :btree
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree
  end

  create_table "games", force: :cascade do |t|
    t.datetime "starts_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lines", force: :cascade do |t|
    t.integer  "contestant_id",                 null: false
    t.string   "type",                          null: false
    t.float    "value",                         null: false
    t.boolean  "hidden",        default: false, null: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.index ["contestant_id"], name: "index_lines_on_contestant_id", using: :btree
    t.index ["type"], name: "index_lines_on_type", using: :btree
  end

  create_table "users", force: :cascade do |t|
    t.boolean  "admin"
    t.string   "name"
    t.string   "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wagers", force: :cascade do |t|
    t.integer  "betting_slip_id", null: false
    t.integer  "line_id",         null: false
    t.datetime "placed_at"
    t.decimal  "amount_wagered"
    t.float    "vig"
    t.integer  "result"
    t.decimal  "net"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["betting_slip_id"], name: "index_wagers_on_betting_slip_id", using: :btree
    t.index ["line_id"], name: "index_wagers_on_line_id", using: :btree
  end

  add_foreign_key "betting_slips", "users"
  add_foreign_key "contestants", "competetors"
  add_foreign_key "contestants", "contests"
  add_foreign_key "contests", "games"
  add_foreign_key "lines", "contestants"
  add_foreign_key "wagers", "betting_slips"
  add_foreign_key "wagers", "lines"
end
