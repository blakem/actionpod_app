class AddTimelimitToPool < ActiveRecord::Migration
  def self.up
    add_column :pools, :timelimit, :integer,  :null => false, :default => 15
    execute("ALTER TABLE pools ALTER COLUMN timelimit DROP DEFAULT")
  end

  def self.down
    remove_column :pools, :timelimit
  end
end
