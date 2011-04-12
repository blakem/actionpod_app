class AddConfirmableToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :confirmation_token,   :string
    add_column :users, :confirmed_at,         :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_index  :users, :confirmation_token,   :unique => true
    execute "update users set confirmed_at=NOW()"
  end

  def self.down
    remove_column :users, :confirmation_token
    remove_column :users, :confirmed_at
    remove_column :users, :confirmation_sent_at
  end
end