class AddHideOptionalFieldsToPool < ActiveRecord::Migration
  def self.up
    add_column :pools, :hide_optional_fields, :boolean
  end

  def self.down
    remove_column :pools, :hide_optional_fields
  end
end
