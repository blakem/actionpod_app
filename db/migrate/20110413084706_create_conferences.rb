class CreateConferences < ActiveRecord::Migration
  def self.up
    create_table :conferences do |t|
      t.string :room_name
      t.string :status
      t.integer :pool_id
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end

  def self.down
    drop_table :conferences
  end
end
