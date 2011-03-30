class AddPrimaryPhoneAndTitleToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :primary_phone, :string
    add_column :users, :title, :string
  end

  def self.down
    remove_column :users, :title
    remove_column :users, :primary_phone
  end
end
