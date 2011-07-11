class AddSessionIdToCalls < ActiveRecord::Migration
  def self.up
    add_column :calls, :session_id, :string
  end

  def self.down
    remove_column :calls, :session_id
  end
end
