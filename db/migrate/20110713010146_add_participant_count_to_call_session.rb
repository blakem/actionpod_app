class AddParticipantCountToCallSession < ActiveRecord::Migration
  def self.up
    add_column :call_sessions, :participant_count, :integer
  end

  def self.down
    remove_column :call_sessions, :participant_count
  end
end
