class AddStatusToCalls < ActiveRecord::Migration
  def self.up
    add_column :calls, :status, :string
  end

  def self.down
    remove_column :calls, :status
  end
end
