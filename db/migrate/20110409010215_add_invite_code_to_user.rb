class AddInviteCodeToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :invite_code, :string
  end

  def self.down
    remove_column :users, :invite_code
  end
end
