class CreatePreferences < ActiveRecord::Migration
  def self.up
    create_table :preferences do |t|
      t.integer :user_id
      t.integer :other_user_id
      t.boolean :prefer_more

      t.timestamps
    end
  end

  def self.down
    drop_table :preferences
  end
end
