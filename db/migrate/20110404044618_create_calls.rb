class CreateCalls < ActiveRecord::Migration
  def self.up
    create_table :calls do |t|
      t.string :Sid
      t.string :DateCreated
      t.string :DateUpdated
      t.string :To
      t.string :From
      t.string :PhoneNumberSid
      t.string :Uri
      t.integer :event_id

      t.timestamps
    end
  end

  def self.down
    drop_table :calls
  end
end
