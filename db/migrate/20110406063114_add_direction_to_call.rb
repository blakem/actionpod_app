class AddDirectionToCall < ActiveRecord::Migration
  def self.up
    add_column :calls, :Direction, :string
  end

  def self.down
    remove_column :calls, :Direction
  end
end
