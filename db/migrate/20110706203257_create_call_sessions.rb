class CreateCallSessions < ActiveRecord::Migration
  def self.up
    create_table :call_sessions do |t|
      t.string :session_id
      t.string :call_id
      t.integer :pool_id
      t.integer :user_id
      t.integer :event_id
      t.string :direction
      t.string :call_state

      t.timestamps
    end
  end

  def self.down
    drop_table :call_sessions
  end
end
