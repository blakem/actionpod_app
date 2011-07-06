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

ActiveRecord::Schema.define(:version => 20110706203257) do

  create_table "call_sessions", :force => true do |t|
    t.string   "session_id"
    t.string   "call_id"
    t.integer  "pool_id"
    t.integer  "user_id"
    t.integer  "event_id"
    t.string   "direction"
    t.string   "call_state"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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
    t.string   "status"
    t.string   "AnsweredBy"
    t.integer  "user_id"
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
    t.integer  "user_id",                             :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "pool_id",                             :null => false
    t.boolean  "send_sms_reminder", :default => true
  end

  create_table "invite_codes", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "member_invites", :force => true do |t|
    t.integer  "sender_id"
    t.integer  "to_id"
    t.integer  "pool_id"
    t.string   "invite_code"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email"
    t.text     "message"
  end

  create_table "member_mails", :force => true do |t|
    t.integer  "user_id"
    t.datetime "sent_at"
    t.string   "email_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "member_messages", :force => true do |t|
    t.integer  "sender_id"
    t.integer  "to_id"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "phones", :force => true do |t|
    t.string   "number"
    t.string   "string"
    t.boolean  "primary",    :default => false
    t.integer  "user_id",                       :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "plans", :force => true do |t|
    t.text     "body"
    t.integer  "user_id",    :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pools", :force => true do |t|
    t.string   "name"
    t.integer  "admin_id",               :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "timelimit",              :null => false
    t.boolean  "hide_optional_fields"
    t.boolean  "public_group"
    t.boolean  "allow_others_to_invite"
    t.text     "description"
    t.string   "available_time_mode"
    t.boolean  "send_conference_email"
    t.integer  "merge_type"
  end

  create_table "pools_users", :id => false, :force => true do |t|
    t.integer "pool_id"
    t.integer "user_id"
  end

  create_table "preferences", :force => true do |t|
    t.integer  "user_id"
    t.integer  "other_user_id"
    t.boolean  "prefer_more"
    t.datetime "created_at"
    t.datetime "updated_at"
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

  create_table "tips", :force => true do |t|
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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
    t.string   "title"
    t.string   "invite_code"
    t.boolean  "use_ifmachine"
    t.datetime "deleted_at"
    t.string   "location"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "handle"
    t.boolean  "hide_email",                          :default => false
    t.text     "about"
    t.string   "facebook_uid"
    t.string   "phonetic_name"
    t.integer  "called_count",                        :default => 0
    t.integer  "answered_count",                      :default => 0
    t.integer  "placed_count",                        :default => 0
    t.integer  "incoming_count",                      :default => 0
    t.integer  "missed_in_a_row",                     :default => 0
    t.integer  "made_in_a_row",                       :default => 0
  end

  add_index "users", ["confirmation_token"], :name => "index_users_on_confirmation_token", :unique => true
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["handle"], :name => "index_users_on_handle", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
