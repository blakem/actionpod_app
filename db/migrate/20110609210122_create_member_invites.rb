class CreateMemberInvites < ActiveRecord::Migration
  def self.up
    create_table :member_invites do |t|
      t.integer :sender_id
      t.integer :to_id
      t.integer :pool_id
      t.string :invite_code
      t.text :body

      t.timestamps
    end
  end

  def self.down
    drop_table :member_invites
  end
end
