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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110413091942) do

  create_table "calls", :force => true do |t|
    t.string   "Sid"
    t.string   "DateCreated"
    t.string   "DateUpdated"
    t.string   "To"
    t.string   "From"
    t.string   "PhoneNumberSid"
    t.string   "Uri"
    t.integer  "event_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "Direction"
    t.integer  "Duration"
  end

  create_table "conferences", :force => true do |t|
    t.string   "room_name"
    t.string   "status"
    t.integer  "pool_id"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "conferences_users", :id => false, :force => true do |t|
    t.integer "conference_id"
    t.integer "user_id"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",    :default => 0
    t.integer  "attempts",    :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.text     "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "obj_type"
    t.integer  "obj_id"
    t.string   "obj_jobtype"
    t.integer  "pool_id"
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "events", :force => true do |t|
    t.string   "name"
    t.text     "schedule_yaml"
    t.integer  "user_id",       :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "pool_id",       :null => false
  end

  create_table "invite_codes", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pools", :force => true do |t|
    t.string   "name"
    t.integer  "user_id",    :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "timelimit",  :null => false
  end

  create_table "rails_admin_histories", :force => true do |t|
    t.string   "message"
    t.string   "username"
    t.integer  "item"
    t.string   "table"
    t.integer  "month",      :limit => 2
    t.integer  "year",       :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "rails_admin_histories", ["item", "table", "month", "year"], :name => "index_histories_on_item_and_table_and_month_and_year"

  create_table "users", :force => true do |t|
    t.string   "email",                               :default => "",    :null => false
    t.string   "encrypted_password",   :limit => 128, :default => "",    :null => false
    t.string   "password_salt",                       :default => "",    :null => false
    t.string   "reset_password_token"
    t.string   "remember_token"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                       :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "admin",                               :default => false
    t.string   "time_zone"
    t.string   "name"
    t.string   "primary_phone"
    t.string   "title"
    t.string   "invite_code"
    t.boolean  "use_ifmachine"
    t.string   "primary_phone_string"
    t.datetime "deleted_at"
    t.string   "location"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
  end

  add_index "users", ["confirmation_token"], :name => "index_users_on_confirmation_token", :unique => true
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
