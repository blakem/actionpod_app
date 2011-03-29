class CreateEvents < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.string :name
      t.text :schedule_yaml
      t.belongs_to :user, :null => false

      t.timestamps
    end
  end

  def self.down
    drop_table :events
  end
end
