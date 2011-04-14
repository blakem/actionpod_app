class AddHideEmailToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :hide_email, :boolean, :default => false
  end

  def self.down
    remove_column :users, :hide_email
  end
end
