class AddPoolIdToEvents < ActiveRecord::Migration
  def self.up
    add_column :events, :pool_id, :integer, :null => false, :default => 1
    execute("ALTER TABLE events ALTER COLUMN pool_id DROP DEFAULT")
  end

  def self.down
    remove_column :events, :pool_id
  end
end
