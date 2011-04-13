class CreateConferencesUsers < ActiveRecord::Migration
  def self.up
    create_table :conferences_users, :id => false do |t|
      t.integer :conference_id
      t.integer :user_id
    end
  end

  def self.down
    drop_table :conferences_users
  end
end
