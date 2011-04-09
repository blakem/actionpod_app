class AddUseIfmachineToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :use_ifmachine, :boolean
  end

  def self.down
    remove_column :users, :use_ifmachine
  end
end
