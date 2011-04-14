class AddHandleToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :handle, :string
    add_index(:users, :handle, :unique => true)
    User.all.each do |u|
      u.handle = u.generate_handle_from_email
      u.save
    end
  end

  def self.down
    remove_column :users, :handle
  end
end
