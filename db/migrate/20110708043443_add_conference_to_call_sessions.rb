class AddConferenceToCallSessions < ActiveRecord::Migration
  def self.up
    add_column :call_sessions, :conference_name, :string
    add_column :call_sessions, :timelimit, :integer
    add_column :call_sessions, :event_ids, :string
  end

  def self.down
    remove_column :call_sessions, :event_ids
    remove_column :call_sessions, :timelimit
    remove_column :call_sessions, :conference_name
  end
end
