class AddDescriptionToPools < ActiveRecord::Migration
  def self.up
    add_column :pools, :description, :text
  end

  def self.down
    remove_column :pools, :description
  end
end
