class AddPublicGroupToPools < ActiveRecord::Migration
  def self.up
    add_column :pools, :public_group, :boolean
  end

  def self.down
    remove_column :pools, :public_group
  end
end
