class AddInarowCountsToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :missed_in_a_row, :integer, :default => 0
    add_column :users, :made_in_a_row, :integer, :default => 0
    execute("update users set missed_in_a_row=0, made_in_a_row=0")
  end

  def self.down
    remove_column :users, :made_in_a_row
    remove_column :users, :missed_in_a_row
  end
end
