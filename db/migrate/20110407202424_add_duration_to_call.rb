class AddDurationToCall < ActiveRecord::Migration
  def self.up
    add_column :calls, :Duration, :integer
  end

  def self.down
    remove_column :calls, :Duration
  end
end
