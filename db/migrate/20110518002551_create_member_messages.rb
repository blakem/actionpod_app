class CreateMemberMessages < ActiveRecord::Migration
  def self.up
    create_table :member_messages do |t|
      t.integer :sender_id
      t.integer :to_id
      t.text :body

      t.timestamps
    end
  end

  def self.down
    drop_table :member_messages
  end
end
