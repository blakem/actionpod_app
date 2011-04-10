class AddPrimaryPhoneStringToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :primary_phone_string, :string
    execute("update users set primary_phone_string=primary_phone")
  end

  def self.down
    remove_column :users, :primary_phone_string
  end
end
